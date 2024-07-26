package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"matchMe/pkg/utils"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		allowedOrigin := "http://localhost:3000"
		origin := r.Header.Get("Origin")
		return origin == allowedOrigin
	},
}

type Client struct {
	conn   *websocket.Conn
	send   chan []byte
	userId string
	rooms  map[string]bool
}

type Room struct {
	id      string
	clients map[string]*Client
}

type App struct {
	DB         *sql.DB
	clients    sync.Map
	rooms      sync.Map
	userStatus sync.Map
}

func (app *App) HandleConnections(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		utils.HandleError(w, "failed to upgrade connection", http.StatusUnauthorized, fmt.Errorf("failed to upgrade connection: %v", err))
		return
	}

	userId := middleware.GetUserId(r)
	client := &Client{conn: conn, send: make(chan []byte, 256), userId: userId, rooms: make(map[string]bool)}

	app.clients.Store(userId, client)
	app.userStatus.Store(userId, true)

	var wg sync.WaitGroup
	wg.Add(2)

	go app.writePump(client, &wg)
	go app.readPump(client, &wg)

	wg.Wait()

	go app.sendInitialData(client)

}

func (app *App) readPump(client *Client, wg *sync.WaitGroup) {
	defer func() {
		app.removeClientFromAllRooms(client)
		app.unregisterClient(client)
		client.conn.Close()
	}()

	client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.conn.SetPongHandler(func(string) error {
		client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	wg.Done()

	for {
		_, message, err := client.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}

		var event models.Event

		if err := json.Unmarshal(message, &event); err != nil {
			log.Printf("error: %v", err)
			break
		}

		switch event.Event {
		case "get_status":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the status request"}`)
				log.Printf("error unmarshaling status request: %v", err)
				continue
			}
			app.handleGetStatus(client, requestData.Id)
		case "send_request":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleSendRequest(client, requestData.Id)
		case "accept_request":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleAcceptRequest(client, requestData.Id)
		case "decline_request":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the decline request"}`)
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleDeclineRequest(client, requestData.Id)
		case "check_new_connection":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the check new connection request"}`)
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleCheckNewConnection(client, requestData.Id)
		case "reject_recommendation":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the rejection request"}`)
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleRejectRecommendation(client, requestData.Id)
		case "leave_room":
			var LeaveRoomData models.LeaveRoom
			if err := json.Unmarshal(event.Data, &LeaveRoomData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the leave room request"}`)
				log.Printf("error unmarshaling leave room data: %v", err)
				continue
			}
			app.handleLeaveRoom(client, LeaveRoomData.RoomId)
		case "send_message":
			var messageData models.Message
			if err := json.Unmarshal(event.Data, &messageData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the send message request"}`)
				log.Printf("error unmarshaling message data: %v", err)
				continue
			}
			app.handleSendMessage(client, messageData)
		case "get_messages":
			var messageData models.GetMessages
			if err := json.Unmarshal(event.Data, &messageData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the get messages request"}`)
				log.Printf("error unmarshaling message data: %v", err)
				continue
			}
			app.handleGetMessages(client, messageData)
		case "check_unread_messages":
			var unreadMessage models.CheckUnreadMessage
			if err := json.Unmarshal(event.Data, &unreadMessage); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the get messages request"}`)
				log.Printf("error unmarshaling message data: %v", err)
				continue
			}
			app.handleCheckUnreadMessages(client, unreadMessage)
		case "get_chat_list":
			app.handleGetChatList(client)
		case "typing":
			var typingData models.Typing
			if err := json.Unmarshal(event.Data, &typingData); err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the typing request"}`)
				log.Printf("error unmarshaling typing data: %v", err)
				continue
			}
			app.handleTyping(client, typingData)
		}
	}
}

func changeToEvent(event string, data interface{}) ([]byte, error) {
	eventData, err := json.Marshal(data)
	if err != nil {
		fmt.Printf("failed to marshal data: %v\n", err)
		return nil, fmt.Errorf("failed to marshal data: %v", err)
	}
	eventStruct := models.Event{
		Event: event,
		Data:  json.RawMessage(eventData),
	}

	return json.Marshal(eventStruct)
}

func (app *App) removeClientFromAllRooms(client *Client) {
	app.rooms.Range(func(key, value interface{}) bool {
		room := value.(*Room)
		delete(room.clients, client.userId)
		if len(room.clients) == 0 {
			app.rooms.Delete(key)
		}
		return true
	})
}

func (app *App) unregisterClient(client *Client) {
	app.clients.Delete(client.userId)
	app.userStatus.Store(client.userId, false)
	close(client.send)

	app.broadcastStatusChange(client.userId, false)
}

func (app *App) broadcastStatusChange(userId string, status bool) {
	var userStatus = models.UserStatus{
		Id:     userId,
		Status: status,
	}

	response, err := changeToEvent("user_status", userStatus)
	if err != nil {
		log.Printf("error marshaling connection status: %v", err)
		return
	}

	getConnectedUsers, err := utils.GetConnectedUsers(app.DB, userId)
	if err != nil {
		log.Printf("error fetching connected users for user %s: %v", userId, err)
		return
	}

	for _, connectedUser := range getConnectedUsers {
		if toClient, ok := app.clients.Load(connectedUser); ok {
			toClient, ok := toClient.(*Client)
			if ok {
				select {
				case toClient.send <- response:
				default:
					log.Printf("Falied to send connection status to user %s\n", connectedUser)
					app.unregisterClient(toClient)
				}
			}
		}
	}
}

func (app *App) writePump(client *Client, wg *sync.WaitGroup) {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		client.conn.Close()
	}()

	wg.Done()

	for {
		select {
		case message, ok := <-client.send:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				client.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := client.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := client.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (app *App) sendInitialData(client *Client) {
	friendRequests, err := utils.GetRequests(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch friend requests"}`)
		log.Printf("error fetching friend requests for user %s: %v\n", client.userId, err)
	} else {
		response, _ := changeToEvent("friend_requests", friendRequests)
		client.send <- response
	}

	hasUnreadMessages, err := utils.HasUnreadMessages(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch unread messages"}`)
		log.Printf("error fetching unread messages for user %s: %v\n", client.userId, err)
	} else {
		response, _ := changeToEvent("unread_messages", hasUnreadMessages)
		client.send <- response
	}

	newConnections, err := utils.GetNewConnections(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch new connections"}`)
		log.Printf("error fetching new connections for user %s: %v\n", client.userId, err)
	} else {
		response, _ := changeToEvent("new_connections", newConnections)
		client.send <- response
	}

	rooms, err := utils.GetUserRooms(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch user rooms"}`)
		log.Printf("error fetching user rooms for user %s: %v\n", client.userId, err)
	}

	for _, roomId := range rooms {
		app.joinRoom(client, roomId)
	}

	app.broadcastStatusChange(client.userId, true)
}

func (app *App) joinRoom(client *Client, roomId string) {
	room, ok := app.rooms.Load(roomId)
	if !ok {
		log.Printf("Room %s not found", roomId)
		return
	}

	r := room.(*Room)
	r.clients[roomId] = client
	client.rooms[roomId] = true
}

func (app *App) handleGetStatus(client *Client, userId string) {
	status, ok := app.userStatus.Load(userId)
	if !ok {
		status = false
	}

	response, err := changeToEvent("user_status", status)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to get user status"}`)
		return
	}

	client.send <- response
}

func (app *App) handleSendRequest(client *Client, toId string) {
	previousRequest, processed, err := utils.SaveRequest(app.DB, client.userId, toId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
		fmt.Printf("error saving friend request from %s to %s: %v\n", client.userId, toId, err)
		return
	}

	if !previousRequest && !processed {
		if toClient, ok := app.clients.Load(toId); ok {
			toclient, ok := toClient.(*Client)
			if ok {
				response, err := changeToEvent("friend_request", client.userId)
				if err != nil {
					client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
					fmt.Printf("error marshaling friend requests: %v\n", err)
					return
				}

				select {
				case toclient.send <- response:
				default:
					client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
					fmt.Printf("Falied to send friend request notification to user %s\n", toId)
					app.unregisterClient(client)
				}
			}
		}
	} else if previousRequest && !processed {
		app.handleCreateRoom(client, toId)

		var sender1 models.NewConnection
		var sender2 models.NewConnection

		numUserId, err := strconv.Atoi(client.userId)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
			fmt.Printf("error converting user id to integer: %v\n", err)
			return
		}

		numToId, err := strconv.Atoi(toId)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
			fmt.Printf("error converting to id to integer: %v\n", err)
			return
		}

		sender1.Id = numUserId
		sender1.IsSender = true
		sender2.Id = numToId
		sender2.IsSender = true

		responseForClient, err := changeToEvent("new_connection", sender2)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
			fmt.Printf("error marshaling connection update: %v\n", err)
			return
		}

		responseForToId, err := changeToEvent("new_connection", sender1)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
			fmt.Printf("error marshaling connection update: %v\n", err)
			return
		}

		app.handleGetChatList(client)
		select {
		case client.send <- responseForClient:
		default:
			client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
			fmt.Printf("Falied to send connection update notification to user %s\n", client.userId)
			app.unregisterClient(client)
		}

		if toClient, ok := app.clients.Load(toId); ok {
			toClient, ok := toClient.(*Client)
			if ok {
				app.handleGetChatList(toClient)
				select {
				case toClient.send <- responseForToId:
				default:
					toClient.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
					fmt.Printf("Falied to send connection update notification to user %s\n", toId)
					app.unregisterClient(toClient)
				}
			}
		}
	}
}

func (app *App) handleAcceptRequest(client *Client, fromId string) {
	err := utils.SaveAcceptance(app.DB, fromId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("error saving acceptance from %s to %s: %v\n", fromId, client.userId, err)
		return
	}

	app.handleCreateRoom(client, fromId)

	var sender1 models.NewConnection
	var sender2 models.NewConnection

	numUserId, err := strconv.Atoi(client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
		fmt.Printf("error converting user id to integer: %v\n", err)
		return
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
		fmt.Printf("error converting to id to integer: %v\n", err)
		return
	}

	sender1.Id = numUserId
	sender1.IsSender = true
	sender2.Id = numFromId
	sender2.IsSender = false

	responseForFromId, err := changeToEvent("new_connection", sender1)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("error marshaling connection update: %v\n", err)
		return
	}

	responseForToId, err := changeToEvent("new_connection", sender2)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("error marshaling connection update: %v\n", err)
		return
	}

	app.handleGetChatList(client)
	select {
	case client.send <- responseForToId:
	default:
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("Falied to send connection update notification to user %s\n", fromId)
		app.unregisterClient(client)
	}

	if toClient, ok := app.clients.Load(fromId); ok {
		toClient, ok := toClient.(*Client)
		if ok {
			app.handleGetChatList(toClient)
			select {
			case toClient.send <- responseForFromId:
			default:
				client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
				fmt.Printf("Falied to send connection update notification to user %s\n", fromId)
				app.unregisterClient(toClient)
			}
		}
	}
}

func (app *App) handleDeclineRequest(client *Client, fromId string) {
	err := utils.SaveDecline(app.DB, fromId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the decline request"}`)
		fmt.Printf("error saving decline from %s to %s: %v\n", fromId, client.userId, err)
		return
	}
}

func (app *App) handleCheckNewConnection(client *Client, fromId string) {
	err := utils.SaveCheckedNewConnection(app.DB, client.userId, fromId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the check new connection request"}`)
		fmt.Printf("error saving checked new connection from %s to %s: %v\n", fromId, client.userId, err)
		return
	}
}

func (app *App) handleRejectRecommendation(client *Client, fromId string) {
	err := utils.SaveRejection(app.DB, fromId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the rejection request"}`)
		fmt.Printf("error saving rejection from %s to %s: %v\n", fromId, client.userId, err)
		return
	}

	response, err := changeToEvent("recommendation_update", true)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the rejection request"}`)
		fmt.Printf("error marshaling recommendation update: %v\n", err)
		return
	}

	select {
	case client.send <- response:
	default:
		client.send <- []byte(`{"event":"error", "data":"unable to process the rejection request"}`)
		fmt.Printf("Falied to send recommendation update notification to user %s\n", fromId)
		app.unregisterClient(client)
	}
}

func (app *App) handleCreateRoom(client *Client, toId string) {
	roomId, err := utils.CreateRoom(app.DB, client.userId, toId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to create room"}`)
		fmt.Printf("error creating room between %s and %s: %v\n", client.userId, toId, err)
		return
	}

	room := &Room{
		id:      roomId,
		clients: make(map[string]*Client),
	}

	app.rooms.Store(roomId, room)
	app.joinRoom(client, roomId)

	if toClient, ok := app.clients.Load(toId); ok {
		toClient, ok := toClient.(*Client)
		if ok {
			app.joinRoom(toClient, roomId)
		}
	}
}

func (app *App) handleLeaveRoom(client *Client, roomId string) {
	utils.SaveLeaveRoom(app.DB, client.userId, roomId)
	room, ok := app.rooms.Load(roomId)
	if !ok {
		log.Printf("Room %s not found", roomId)
		return
	}
	r := room.(*Room)
	delete(r.clients, client.userId)

	if len(r.clients) == 0 {
		app.rooms.Delete(roomId)
	}
}

func (app *App) handleSendMessage(client *Client, messageInfo models.Message) {
	canGetMessages, err := utils.CanGetMessagesUsingIds(app.DB, client.userId, messageInfo.ToId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to send message"}`)
		fmt.Printf("error checking if user %s can get messages from %s: %v\n", client.userId, messageInfo.ToId, err)
		return
	}

	messageInfo.FromId = client.userId
	messageInfo.CanGetMessages = canGetMessages

	messageId, err := utils.SaveMessage(app.DB, messageInfo.RoomId, client.userId, messageInfo.ToId, messageInfo.Message, messageInfo.SentAt, messageInfo.CanGetMessages)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to send message"}`)
		fmt.Printf("error saving message from %s to %s: %v\n", client.userId, messageInfo.ToId, err)
		return
	}

	messageInfo.Id = messageId

	if canGetMessages {
		if toClient, ok := app.clients.Load(messageInfo.ToId); ok {
			toClient, ok := toClient.(*Client)
			if ok {
				chatList, err := utils.GetChatList(app.DB, messageInfo.ToId)
				if err != nil {
					client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
					fmt.Printf("error fetching chat list for user %s: %v\n", messageInfo.ToId, err)
					return
				}
				response, err := changeToEvent("get_chat_list", chatList)
				if err != nil {
					client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
					fmt.Printf("error marshaling chat list: %v\n", err)
					return
				}

				select {
				case toClient.send <- response:
				default:
					toClient.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
					fmt.Printf("Falied to send chat list to user %s\n", messageInfo.ToId)
					app.unregisterClient(toClient)
				}
			}
		}
	}

	app.broadcastToRoom(messageInfo)
}

func (app *App) broadcastToRoom(messageInfo models.Message) {
	response, err := changeToEvent("new_message", messageInfo)
	if err != nil {
		log.Printf("error marshaling new message: %v", err)
		return
	}

	room, ok := app.rooms.Load(messageInfo.RoomId)
	if !ok {
		log.Printf("Room %s not found", messageInfo.RoomId)
		return
	}

	r := room.(*Room)

	for _, client := range r.clients {
		select {
		case client.send <- response:
		default:
			app.unregisterClient(client)
		}
	}
}

func (app *App) handleGetMessages(client *Client, messageInfo models.GetMessages) {
	canGetMessages, err := utils.CanGetMessagesUsingRoomId(app.DB, messageInfo.RoomId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to get message"}`)
		fmt.Printf("error checking if user %s can get messages: %v\n", client.userId, err)
		return
	}

	if canGetMessages {
		messages, err := utils.GetMessagesForRoom(app.DB, messageInfo.RoomId, client.userId, messageInfo.LastMessageId)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to get messages"}`)
			fmt.Printf("error fetching messages for room %s: %v\n", messageInfo.RoomId, err)
			return
		}

		err = utils.MarkMessagesAsRead(app.DB, client.userId, messageInfo.RoomId)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to mark messages as read"}`)
			fmt.Printf("error marking messages as read for room %s: %v\n", messageInfo.RoomId, err)
			return
		}

		chatList, err := utils.GetChatList(app.DB, client.userId)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
			fmt.Printf("error fetching chat list for user %s: %v\n", client.userId, err)
			return
		}

		messageResponse, err := changeToEvent("get_messages", messages)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to get messages"}`)
			fmt.Printf("error marshaling messages: %v\n", err)
			return
		}

		chatListResponse, err := changeToEvent("get_chat_list", chatList)
		if err != nil {
			client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
			fmt.Printf("error marshaling chat list: %v\n", err)
			return
		}

		select {
		case client.send <- messageResponse:
		default:
			client.send <- []byte(`{"event":"error", "data":"unable to get messages"}`)
			fmt.Printf("Falied to send messages to user %s\n", client.userId)
			app.unregisterClient(client)
		}

		select {
		case client.send <- chatListResponse:
		default:
			client.send <- []byte(`{"event":"error", "data":"unable to get messages"}`)
			fmt.Printf("Falied to send messages to user %s\n", client.userId)
			app.unregisterClient(client)
		}
	}

}

func (app *App) handleCheckUnreadMessages(client *Client, checkUnreadMessage models.CheckUnreadMessage) {
	err := utils.MarkMessagesAsRead(app.DB, client.userId, checkUnreadMessage.RoomId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to mark messages as read"}`)
		fmt.Printf("error marking messages as read for room %s: %v\n", checkUnreadMessage.RoomId, err)
		return
	}

	chatList, err := utils.GetChatList(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
		fmt.Printf("error fetching chat list for user %s: %v\n", client.userId, err)
		return
	}

	response, err := changeToEvent("get_chat_list", chatList)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to check unread messages"}`)
		fmt.Printf("error marshaling chat list: %v\n", err)
		return
	}

	select {
	case client.send <- response:
	default:
		client.send <- []byte(`{"event":"error", "data":"unable to check unread messages"}`)
		fmt.Printf("Falied to send check unread messages to user %s\n", client.userId)
		app.unregisterClient(client)
	}
}

func (app *App) handleGetChatList(client *Client) {
	chatList, err := utils.GetChatList(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
		fmt.Printf("error fetching chat list for user %s: %v\n", client.userId, err)
		return
	}

	response, err := changeToEvent("get_chat_list", chatList)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
		fmt.Printf("error marshaling chat list: %v\n", err)
		return
	}

	select {
	case client.send <- response:
	default:
		client.send <- []byte(`{"event":"error", "data":"unable to get chat list"}`)
		fmt.Printf("Falied to send chat list to user %s\n", client.userId)
		app.unregisterClient(client)
	}
}

func (app *App) handleTyping(client *Client, typingData models.Typing) {
	if toClient, ok := app.clients.Load(typingData.ToId); ok {
		toClient, ok := toClient.(*Client)
		if ok {
			response, err := changeToEvent("typing", typingData.RoomId)
			if err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to send typing notification"}`)
				fmt.Printf("error marshaling typing notification: %v\n", err)
				return
			}

			select {
			case toClient.send <- response:
			default:
				toClient.send <- []byte(`{"event":"error", "data":"unable to send typing notification"}`)
				fmt.Printf("Falied to send typing notification to user %s\n", typingData.ToId)
				app.unregisterClient(toClient)
			}
		}
	}
}

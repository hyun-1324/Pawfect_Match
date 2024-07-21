package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
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
	DB      *sql.DB
	clients sync.Map
	rooms   sync.Map
}

func (app *App) HandleConnections(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Fatalf("Failed to upgrade connection: %v", err)
	}

	userId := middleware.GetUserId(r)
	client := &Client{conn: conn, send: make(chan []byte, 256), userId: userId}

	app.clients.Store(userId, client)

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
		case "send_request":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleSendRequest(client, requestData.Id)
		case "accept_request":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleAcceptRequest(client, requestData.Id)
		case "decline_request":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleDeclineRequest(client, requestData.Id)
		case "reject_recommendation":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				log.Printf("error unmarshaling request data: %v", err)
				continue
			}
			app.handleRejectRecommendation(client, requestData.Id)
		case "create_room":
			var requestData models.RequestData
			if err := json.Unmarshal(event.Data, &requestData); err != nil {
				log.Printf("error unmarshaling create room request: %v", err)
				continue
			}
			app.handleCreateRoom(client, requestData.Id)
		case "join_room":
			app.handleJoinRoom(client, event.Data)
		case "leave_room":
			app.handleLeaveRoom(client, event.Data)
		case "send_message":
			app.handleSendMessage(client, event.Data)
		case "get_messages":
		}
	}
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
	close(client.send)
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
	friendRequests, err := getRequests(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch friend requests"}`)
		log.Printf("error fetching friend requests for user %s: %v\n", client.userId, err)
	} else {
		response, _ := changeToEvent("friendRequests", friendRequests)
		client.send <- response
	}

	hasUnreadMessages, err := checkUnreadMessages(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch unread messages"}`)
		log.Printf("error fetching unread messages for user %s: %v\n", client.userId, err)
	} else {
		response, _ := changeToEvent("unreadMessages", hasUnreadMessages)
		client.send <- response
	}

	rooms, err := getUserRooms(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch user rooms"}`)
		log.Printf("error fetching user rooms for user %s: %v\n", client.userId, err)
	}

	for _, roomId := range rooms {
		app.joinRoom(client, roomId)
	}
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

func (app *App) handleSendRequest(client *Client, toId string) {
	err := saveRequest(app.DB, client.userId, toId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
		fmt.Printf("error saving friend request from %s to %s: %v\n", client.userId, toId, err)
		return
	}

	friendRequests, err := getRequests(app.DB, toId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
		fmt.Printf("error fetching friend requests for user %s: %v\n", toId, err)
		return
	}

	if toClient, ok := app.clients.Load(toId); ok {
		client, ok := toClient.(*Client)
		if ok {
			response, err := changeToEvent("friendRequests", friendRequests)
			if err != nil {
				client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
				fmt.Printf("error marshaling friend requests: %v\n", err)
				return
			}

			select {
			case client.send <- response:
			default:
				client.send <- []byte(`{"event":"error", "data":"unable to process the send request"}`)
				fmt.Printf("Falied to send friend request notification to user %s\n", toId)
				app.unregisterClient(client)
			}
		}
	}
}

func (app *App) handleAcceptRequest(client *Client, fromId string) {
	err := saveAcceptance(app.DB, fromId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("error saving acceptance from %s to %s: %v\n", fromId, client.userId, err)
		return
	}

	response, err := changeToEvent("connection_update", `"connection_update": "true"`)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("error marshaling connection update: %v\n", err)
		return
	}

	select {
	case client.send <- response:
	default:
		client.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
		fmt.Printf("Falied to send connection update notification to user %s\n", fromId)
		app.unregisterClient(client)
	}

	if toClient, ok := app.clients.Load(fromId); ok {
		toClient, ok := toClient.(*Client)
		if ok {
			select {
			case toClient.send <- response:
			default:
				toClient.send <- []byte(`{"event":"error", "data":"unable to process the acceptance request"}`)
				fmt.Printf("Falied to send connection update notification to user %s\n", fromId)
				app.unregisterClient(toClient)
			}
		}
	}
}

func (app *App) handleDeclineRequest(client *Client, fromId string) {
	err := saveDecline(app.DB, fromId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the decline request"}`)
		fmt.Printf("error saving decline from %s to %s: %v\n", fromId, client.userId, err)
		return
	}
}

func (app *App) handleRejectRecommendation(client *Client, fromId string) {
	err := saveRejection(app.DB, fromId, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to process the rejection request"}`)
		fmt.Printf("error saving rejection from %s to %s: %v\n", fromId, client.userId, err)
		return
	}

	response, err := changeToEvent("recommendation_update", `"recommendation_update": "true"`)
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

	roomId, err := createRoom(app.DB, client.userId, toId)
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

	data := map[string]string{"roomId": roomId}

	response, err := changeToEvent("room_created", data)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to create room"}`)
		fmt.Printf("error marshaling room created event: %v\n", err)
		return
	}

	client.send <- response
}

func (app *App) handleJoinRoom(client *Client, data json.RawMessage) {
	var roomData struct {
		RoomId string `json:"roomId"`
	}
	if err := json.Unmarshal(data, &roomData); err != nil {
		log.Printf("error unmarshaling room data: %v", err)
		return
	}

	app.joinRoom(client, roomData.RoomId)

	response := map[string]string{"event": "room_joined", "roomId": roomData.RoomId}
	jsonResponse, _ := json.Marshal(response)
	client.send <- jsonResponse
}

func (app *App) handleLeaveRoom(client *Client, data json.RawMessage) {
	var roomData struct {
		RoomId string `json:"roomId"`
	}
	if err := json.Unmarshal(data, &roomData); err != nil {
		log.Printf("error unmarshaling room data: %v", err)
		return
	}

	app.leaveRoom(client, roomData.RoomId)

	response := map[string]string{"event": "room_left", "roomId": roomData.RoomId}
	jsonResponse, _ := json.Marshal(response)
	client.send <- jsonResponse
}

func (app *App) handleSendMessage(client *Client, data json.RawMessage) {
	var messageData struct {
		RoomId  string `json:"roomId"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(data, &messageData); err != nil {
		log.Printf("error unmarshaling message data: %v", err)
		return
	}

	app.broadcastToRoom(messageData.RoomId, client.userId, messageData.Message)
}

func (app *App) leaveRoom(client *Client, roomId string) {
	room, ok := app.rooms.Load(roomId)
	if !ok {
		log.Printf("Room %s not found", roomId)
		return
	}

	r := room.(*Room)
	delete(r.clients, client)
	client.roomId = ""

	if len(r.clients) == 0 {
		app.rooms.Delete(roomId)
	}
}

func (app *App) broadcastToRoom(roomId, senderId, message string) {
	room, ok := app.rooms.Load(roomId)
	if !ok {
		log.Printf("Room %s not found", roomId)
		return
	}

	r := room.(*Room)
	messageData := map[string]string{
		"event":    "new_message",
		"senderId": senderId,
		"message":  message,
	}
	jsonMessage, _ := json.Marshal(messageData)

	for client := range r.clients {
		select {
		case client.send <- jsonMessage:
		default:
			app.unregisterClient(client)
		}
	}
}

func (app *App) SendToUser(userId string, message []byte) {
	if client, ok := app.clients.Load(userId); ok {
		client.(*Client).send <- message
	}
}

func (app *App) Broadcast(message []byte) {
	app.clients.Range(func(key, value interface{}) bool {
		client := value.(*Client)
		select {
		case client.send <- message:
		default:
			app.unregisterClient(client)
		}
		return true
	})
}

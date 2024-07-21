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

		var event struct {
			Event string          `json:"event"`
			Data  json.RawMessage `json:"data"`
		}

		if err := json.Unmarshal(message, &event); err != nil {
			log.Printf("error: %v", err)
			break
		}

		switch event.Event {
		case "create_room":
			app.handleCreateRoom(client, event.Data)
		case "join_room":
			app.handleJoinRoom(client, event.Data)
		case "leave_room":
			app.handleLeaveRoom(client, event.Data)
		case "send_message":
			app.handleSendMessage(client, event.Data)
		case "send_request":
			app.handleSendRequest(client, event.Data)
		case "accept_request":
			app.handleAcceptRequest(client, event.Data)
			//add event handler
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
		response, _ := json.Marshal(map[string]interface{}{
			"event": "friendRequests",
			"data":  friendRequests,
		})
		client.send <- response
	}

	hasUnreadMessages, err := checkUnreadMessages(app.DB, client.userId)
	if err != nil {
		client.send <- []byte(`{"event":"error", "data":"unable to fetch unread messages"}`)
		log.Printf("error fetching unread messages for user %s: %v\n", client.userId, err)
	} else {
		response, _ := json.Marshal(map[string]interface{}{
			"event": "check_unread_messages",
			"data":  hasUnreadMessages,
		})
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

func (app *App) handleCreateRoom(client *Client, data json.RawMessage) {
	var roomData struct {
		RoomId string `json:"roomId"`
	}
	if err := json.Unmarshal(data, &roomData); err != nil {
		log.Printf("error unmarshaling room data: %v", err)
		return
	}

	room := &Room{
		id:      roomData.RoomId,
		clients: make(map[string]*Client),
	}
	app.rooms.Store(roomData.RoomId, room)
	app.joinRoom(client, roomData.RoomId)

	response := map[string]string{"event": "room_created", "roomId": roomData.RoomId}
	jsonResponse, _ := json.Marshal(response)
	client.send <- jsonResponse
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

func (app *App) handleSendRequest(client *Client, data json.RawMessage) {
	// 요청 처리 로직 구현
	// app.DB를 사용하여 데이터베이스 작업 수행
}

func (app *App) handleAcceptRequest(client *Client, data json.RawMessage) {
	// 수락 요청 처리 로직 구현
	// app.DB를 사용하여 데이터베이스 작업 수행
}

func (app *App) SendToUser(userId string, message []byte) {
	if client, ok := app.clients.Load(userId); ok {
		client.(*Client).send <- message
	}
}

// 새로운 메서드: 모든 연결된 클라이언트에게 브로드캐스트
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

func getRequests(db *sql.DB, userId string) (models.IdList, error) {
	query := `
	SELECT from_id 
	FROM requests 
	JOIN matches 
		ON (
		(matches.user_id1 = requests.from_id AND matches.user_id2 = requests.to_id)
		OR 
		(matches.user_id1 = requests.to_id AND matches.user_id2 = requests.from_id)
		) 
	WHERE requests.to_id = $1 
	AND requests.processed = FALSE 
	AND matches.requested = TRUE 
	AND matches.rejected = FALSE
	`
	rows, err := db.Query(query, userId)
	if err != nil {
		return models.IdList{}, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			return models.IdList{}, fmt.Errorf("failed to scan row: %v", err)
		}
		ids = append(ids, id)
	}

	if err = rows.Err(); err != nil {
		return models.IdList{}, fmt.Errorf("error iterating rows: %v", err)
	}

	return models.IdList{Ids: ids}, nil
}

func checkUnreadMessages(db *sql.DB, userId string) (bool, error) {
	query := `SELECT EXISTS (SELECT 1 FROM messages WHERE to_id = $1 AND read = FALSE)`

	var exists bool
	err := db.QueryRow(query, userId).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check unread messages: %v", err)
	}

	return exists, nil
}

func getUserRooms(db *sql.DB, userId string) ([]string, error) {
	query := `
		SELECT id 
		FROM rooms 
		WHERE user_id1 = $1 OR user_id2 = $1
	`
	rows, err := db.Query(query, userId)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var rooms []string
	for rows.Next() {
		var roomId string
		err := rows.Scan(&roomId)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %v", err)
		}
		rooms = append(rooms, roomId)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating rows: %v", err)
	}

	return rooms, nil
}

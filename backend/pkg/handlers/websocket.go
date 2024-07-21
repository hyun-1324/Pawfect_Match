package handlers

import (
	"database/sql"
	"encoding/json"
	"log"
	"matchMe/pkg/middleware"
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

// type WebSocketManager struct {
// 	clients    map[*Client]bool
// 	broadcast  chan []byte
// 	register   chan *Client
// 	unregister chan *Client
// }

// func NewWebSocketManager() *WebSocketManager {
// 	return &WebSocketManager{
// 		clients:    make(map[*Client]bool),
// 		broadcast:  make(chan []byte),
// 		register:   make(chan *Client),
// 		unregister: make(chan *Client),
// 	}
// }

// func (manager *WebSocketManager) Run() {
// 	for {
// 		select {
// 		case client := <-manager.register:
// 			manager.clients[client] = true
// 		case client := <-manager.unregister:
// 			if _, ok := manager.clients[client]; ok {
// 				delete(manager.clients, client)
// 				close(client.send)
// 			}
// 		case message := <-manager.broadcast:
// 			for client := range manager.clients {
// 				select {
// 				case client.send <- message:
// 				default:
// 					close(client.send)
// 					delete(manager.clients, client)
// 				}
// 			}
// 		}
// 	}
// }

type Client struct {
	conn   *websocket.Conn
	send   chan []byte
	userId string
}

type Room struct {
	id      string
	clients map[*Client]bool
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

	go app.readPump(client)
	go app.writePump(client)

}

func (app *App) readPump(client *Client) {
	defer func() {
		app.unregisterClient(client)
		client.conn.Close()
	}()

	client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.conn.SetPongHandler(func(string) error {
		client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

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
		case "send_request":
			app.handleSendRequest(client, event.Data)
		case "accept_request":
			app.handleAcceptRequest(client, event.Data)
			//add event handler
		}
	}
}

func (app *App) writePump(client *Client) {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		client.conn.Close()
	}()

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

func (app *App) unregisterClient(client *Client) {
	app.clients.Delete(client.userId)
	close(client.send)
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

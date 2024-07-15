package handlers

import (
	"database/sql"
	"fmt"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"matchMe/pkg/util"
	"net/http"
	"strconv"
	"sync"
	"time"

	socketio "github.com/googollee/go-socket.io"
)

func RegisterSocketHandlers(server *socketio.Server, db *sql.DB) {

	var userConnections = struct {
		sync.RWMutex
		connections map[string]socketio.Conn
	}{connections: make(map[string]socketio.Conn)}

	server.OnConnect("/", func(s socketio.Conn) error {
		headers := s.RemoteHeader()
		cookieHeader := headers.Get("Cookie")

		if cookieHeader == "" {
			return fmt.Errorf("unauthorized: no token found in cookie")
		}

		token := extractJWTFromCookieHeader(cookieHeader)

		userId, _, err := middleware.ValidateJWT(db, token)
		if err != nil {
			return fmt.Errorf("unauthorized: invalid token")
		}

		s.SetContext(userId)

		userConnections.Lock()
		userConnections.connections[userId] = s
		userConnections.Unlock()

		friendRequests, err := getRequests(db, userId)
		if err != nil {
			s.Emit("error", "failed to fetch friend requests")
			return fmt.Errorf("failed to fetch friend requests: %v", err)
		}

		s.Emit("friendRequests", friendRequests)

		hasUnreadMessages, err := checkUnreadMessages(db, userId)
		if err != nil {
			s.Emit("error", "Failed to fetch unread messages")
			return fmt.Errorf("failed to fetch unread messages: %v", err)
		}

		s.Emit("check_unread_messages", hasUnreadMessages)

		rooms, err := getUserRooms(db, userId)
		if err != nil {
			s.Emit("error", "failed to fetch user rooms")
			return fmt.Errorf("failed to fetch user rooms: %v", err)
		}

		for _, roomId := range rooms {
			s.Join(roomId)
		}

		return nil
	})

	server.OnError("/", func(s socketio.Conn, e error) {
		fmt.Println("Meet error:", e)
	})

	server.OnDisconnect("/", func(s socketio.Conn, reason string) {
		userId := s.Context().(string)

		userConnections.Lock()
		delete(userConnections.connections, userId)
		userConnections.Unlock()

		fmt.Println("disconnected", reason, "user_id", userId)
	})

	server.OnEvent("/", "send_request", func(s socketio.Conn, msg map[string]interface{}) {
		fromId := s.Context().(string)
		toId, ok := msg["to_id"].(string)
		if !ok {
			s.Emit("error", "to_id is missing")
			return
		}

		err := saveRequest(db, fromId, toId)
		if err != nil {
			s.Emit("error", "failed to save friend request")
			return
		}

		friendRequests, err := getRequests(db, toId)
		if err != nil {
			s.Emit("error", "failed to fetch friend requests")
			return
		}

		userConnections.RLock()
		receiverConn, exists := userConnections.connections[toId]
		userConnections.RUnlock()

		if exists {
			receiverConn.Emit("friendRequests", friendRequests)
		}

	})

	server.OnEvent("/", "accept_request", func(s socketio.Conn, msg map[string]interface{}) {
		toId := s.Context().(string)
		fromId, ok := msg["from_id"].(string)
		if !ok {
			s.Emit("error", "from_id is missing")
			return
		}

		err := saveAcceptance(db, fromId, toId)
		if err != nil {
			s.Emit("error", "failed to save acceptance")
			return
		}

		s.Emit("connection_update_notification", true)

		userConnections.RLock()
		receiverConn, exists := userConnections.connections[fromId]
		userConnections.RUnlock()

		if exists {
			receiverConn.Emit("connection_update_notification", true)
		}

	})

	server.OnEvent("/", "decline_request", func(s socketio.Conn, msg map[string]interface{}) {
		toId := s.Context().(string)
		fromId, ok := msg["from_id"].(string)
		if !ok {
			s.Emit("error", "from_id is missing")
			return
		}

		err := saveDecline(db, fromId, toId)
		if err != nil {
			s.Emit("error", "failed to decline request")
			return
		}
	})

	server.OnEvent("/", "reject_recommendation", func(s socketio.Conn, msg map[string]interface{}) {
		toId := s.Context().(string)
		fromId, ok := msg["from_id"].(string)
		if !ok {
			s.Emit("error", "from_id is missing")
			return
		}

		err := rejectRecommendation(db, fromId, toId)
		if err != nil {
			s.Emit("error", "failed to reject recommendation")
			return
		}

		s.Emit("recommendation_update_notification", true)

	})

	server.OnEvent("/", "create_room", func(s socketio.Conn, msg map[string]interface{}) {
		fromId := s.Context().(string)
		toId, ok := msg["to_id"].(string)
		if !ok {
			s.Emit("error", "to_id is missing")
			return
		}

		roomId, err := createRoom(db, fromId, toId)
		if err != nil {
			s.Emit("error", "failed to create room")
			return
		}

		s.Join(roomId)
		userConnections.RLock()
		receiverConn, exists := userConnections.connections[toId]
		userConnections.RUnlock()

		if exists {
			receiverConn.Join(roomId)
		}

		s.Emit("roomCreated", roomId)
	})

	server.OnEvent("/", "send_message", func(s socketio.Conn, msg map[string]interface{}) {
		fromId := s.Context().(string)
		roomId, ok := msg["room_id"].(string)
		if !ok {
			s.Emit("error", "room_id is missing")
			return
		}
		message, ok := msg["message"].(string)
		if !ok {
			s.Emit("error", "message is missing")
			return
		}
		if len([]byte(message)) > 255 {
			s.Emit("error", "message is too long")
			return
		}

		toId, ok := msg["to_id"].(string)
		if !ok {
			s.Emit("error", "to_id is missing")
			return
		}

		messageId, err := saveMessage(db, roomId, fromId, toId, message)
		if err != nil {
			s.Emit("error", "failed to save message")
			return
		}

		userConnections.RLock()
		receiverConn, exists := userConnections.connections[toId]
		userConnections.RUnlock()

		if exists {
			chatList, err := getChatList(db, toId)
			if err != nil {
				s.Emit("error", "failed to fetch chat list")
				return
			}
			receiverConn.Emit("get_chat_list", chatList)
		}

		server.BroadcastToRoom("/", roomId, "new_message", models.Message{
			Id:      messageId,
			RoomID:  roomId,
			FromID:  fromId,
			ToID:    toId,
			Message: message,
			SentAt:  time.Now(),
		})
	})

	server.OnEvent("/", "get_messages", func(s socketio.Conn, msg map[string]interface{}) {
		userId := s.Context().(string)
		roomId, ok := msg["room_id"].(string)
		if !ok {
			s.Emit("error", "room_id is missing")
			return
		}
		lastMessageId, ok := msg["last_message_id"].(int)
		if !ok {
			s.Emit("error", "last_message_id is missing")
			return
		}

		messages, err := getMessagesForRoom(db, roomId, userId, lastMessageId)
		if err != nil {
			s.Emit("error", "Failed to fetch messages")
			return
		}

		err = markMessagesAsRead(db, userId, roomId)
		if err != nil {
			s.Emit("error", "Failed to mark messages as read")
			return
		}

		chatList, err := getChatList(db, userId)
		if err != nil {
			s.Emit("error", "failed to fetch chat list")
			return
		}
		s.Emit("get_chat_list", chatList)

		s.Emit("room_messages", messages)
	})

	server.OnEvent("/", "check_unread_message", func(s socketio.Conn) {
		userId := s.Context().(string)
		hasUnreadMessages, err := checkUnreadMessages(db, userId)
		if err != nil {
			s.Emit("error", "failed to check unread messages")
			return
		}
		s.Emit("check_unread_message", hasUnreadMessages)
	})

	server.OnEvent("/", "get_chat_list", func(s socketio.Conn) {
		userId := s.Context().(string)
		chatList, err := getChatList(db, userId)
		if err != nil {
			s.Emit("error", "Failed to fetch unread messages")
			return
		}
		s.Emit("get_unread_messages", chatList)
	})
}

func extractJWTFromCookieHeader(cookieHeader string) string {
	header := http.Header{}
	header.Add("Cookie", cookieHeader)
	request := http.Request{Header: header}

	cookie, err := request.Cookie("jwt_token")
	if err != nil {
		return ""
	}
	return cookie.Value
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

func saveRequest(db *sql.DB, fromId, toId string) error {

	_, err := db.Exec("INSERT INTO requests (from_id, to_id) VALUES ($1, $2)", fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to execute query: %v", err)
	}

	_, err = db.Exec("UPDATE matches SET requested = TRUE WHERE (user_id1 = $1 AND user_id2 = $2) OR (user_id1 = $2 AND user_id2 = $1)", fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to execute query: %v", err)
	}

	return nil
}

func saveAcceptance(db *sql.DB, fromId, toId string) error {

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return err
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return err
	}

	smallId, largeId := util.OrderPair(numToId, numFromId)

	_, err = db.Exec("INSERT INTO connections (user_id1, user_id2) VALUES ($1, $2) ON CONFLICT (user_id1, user_id2) DO NOTHING", smallId, largeId)
	if err != nil {
		return err
	}

	_, err = db.Exec("UPDATE requests SET processed = TRUE, accepted = TRUE WHERE from_id = $1 AND to_id = $2", fromId, toId)
	if err != nil {
		return err
	}

	return nil
}

func saveDecline(db *sql.DB, fromId, toId string) error {

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return err
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return err
	}

	smallId, largeId := util.OrderPair(numToId, numFromId)

	query := "UPDATE requests SET processed = TRUE WHERE from_id = $1 AND to_id = $2"
	_, err = db.Exec(query, fromId, toId)
	if err != nil {
		return err
	}

	query = "UPDATE matches SET rejected = TRUE WHERE from_id = $1 AND to_id = $2"
	_, err = db.Exec(query, smallId, largeId)
	if err != nil {
		return err
	}

	return nil
}

func rejectRecommendation(db *sql.DB, fromId, toId string) error {

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return err
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return err
	}

	smallId, largeId := util.OrderPair(numToId, numFromId)

	query := "UPDATE matches SET rejected = TRUE WHERE from_id = $1 AND to_id = $2"
	_, err = db.Exec(query, smallId, largeId)
	if err != nil {
		return err
	}

	query = `
	UPDATE requests 
	SET processed = TRUE 
	WHERE (
	(from_id = $1 AND to_id = $2) 
	OR 
	(from_id = $2 AND to_id = $1))
	`
	_, err = db.Exec(query, fromId, toId)
	if err != nil {
		return err
	}

	return nil
}

func createRoom(db *sql.DB, fromId, toId string) (string, error) {
	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return "", err
	}
	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return "", err
	}

	smallId, largeId := util.OrderPair(numFromId, numToId)

	var roomId string
	err = db.QueryRow(`
		INSERT INTO rooms (user_id1, user_id2) 
		VALUES ($1, $2) 
		ON CONFLICT (user_id1, user_id2) DO NOTHING 
		RETURNING id`, smallId, largeId).Scan(&roomId)

	if err != nil {
		return "", fmt.Errorf("failed to create or get room: %v", err)
	}

	return roomId, nil
}

func saveMessage(db *sql.DB, roomId, fromId, toId, message string) (int, error) {

	var messageId int
	err := db.QueryRow("INSERT INTO messages (room_id, from_id, to_id, message) VALUES ($1, $2, $3, $4) RETURNING id", roomId, fromId, toId, message).Scan(&messageId)
	if err != nil {
		return 0, fmt.Errorf("failed to save message: %v", err)
	}

	return messageId, nil
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

func getChatList(db *sql.DB, userId string) ([]models.ChatList, error) {
	query := `
SELECT 
  room_id,
  EXISTS (
    SELECT 1
    FROM messages m
    WHERE m.room_id = messages.room_id AND m.read = FALSE
  ) AS has_unread
FROM messages 
WHERE (to_id = $1 OR from_id = $1)
GROUP BY room_id
ORDER BY MAX(sent_at) DESC;
	`
	rows, err := db.Query(query, userId)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var chatList []models.ChatList
	for rows.Next() {
		var msg models.ChatList
		err := rows.Scan(&msg.RoomId, &msg.UnReadMessage)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %v", err)
		}
		chatList = append(chatList, msg)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating rows: %v", err)
	}

	return chatList, nil
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

func getMessagesForRoom(db *sql.DB, roomId string, userId string, lastMessageId int) ([]models.Message, error) {
	limit := 10

	query := `
	SELECT id, room_id, from_id, to_id, message, sent_at
	FROM messages
	WHERE room_id = $1 AND (from_id = $2 OR to_id = $2) AND id < $3
	ORDER BY sent_at DESC
	LIMIT $4
	`

	rows, err := db.Query(query, roomId, userId, lastMessageId, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var messages []models.Message
	for rows.Next() {
		var msg models.Message
		err := rows.Scan(&msg.Id, &msg.RoomID, &msg.FromID, &msg.ToID, &msg.Message, &msg.SentAt)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %v", err)
		}
		messages = append(messages, msg)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating rows: %v", err)
	}

	return messages, nil
}

func markMessagesAsRead(db *sql.DB, userId, roomId string) error {
	query := `
	UPDATE messages
	SET read = TRUE
	WHERE to_id = $1 AND room_id = $2
	`
	_, err := db.Exec(query, userId, roomId)
	if err != nil {
		return fmt.Errorf("failed to mark messages as read: %v", err)
	}

	return nil

}

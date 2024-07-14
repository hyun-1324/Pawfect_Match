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

		// unreadMessages := getUnreadMessages(db, userId)

		s.Emit("friendRequests", friendRequests)
		// s.Emit("unreadMessages", unreadMessages)

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

		userConnections.RLock()
		receiverConn, exists := userConnections.connections[fromId]
		userConnections.RUnlock()

		if exists {
			receiverConn.Emit("recommendation_update_notification", true)
		}
	})

	// server.OnEvent("/", "join", func(s socketio.Conn, room string) {
	// 	userId := s.Context().(string)
	// 	s.Join(room)
	// 	fmt.Println("joined", userId, room)
	// })

	// server.OnEvent("/", "message", func(s socketio.Conn, msg map[string]interface{}) {
	// 	fromId := s.Context().(string)
	// 	toId := msg["receiver_id"].(string)
	// 	message := msg["message"].(string)
	// 	room := fmt.Sprintf("%s-%s", fromId, toId)

	// 	server.BroadcastToRoom("/", room, "message", map[string]interface{}{
	// 		"sender_id":   fromId,
	// 		"message":     message,
	// 		"receiver_id": toId,
	// 	})
	// })

	// server.OnEvent("/", "typing", func(s socketio.Conn, msg map[string]interface{}) {
	// 	userId := s.Context().(string)
	// 	toId := msg["receiver_id"].(string)
	// 	room := fmt.Sprintf("%s-%s", userId, toId)

	// 	server.BroadcastToRoom("/", room, "typing", map[string]interface{}{
	// 		"user_id": userId,
	// 		"typing":  true,
	// 	})
	// })

	// server.OnEvent("/", "stop_typing", func(s socketio.Conn, msg map[string]interface{}) {
	// 	userId := s.Context().(string)
	// 	toId := msg["receiver_id"].(string)
	// 	room := fmt.Sprintf("%s-%s", userId, toId)

	// 	server.BroadcastToRoom("/", room, "typing", map[string]interface{}{
	// 		"user_id": userId,
	// 		"typing":  false,
	// 	})
	// })

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

func saveMessageToDB(db *sql.DB, fromId, toId, message string) error {
	query := "INSERT INTO messages (sender_id, receiver_id, message) VALUES (?, ?, ?)"
	_, err := db.Exec(query, fromId, toId, message)
	if err != nil {
		return err
	}
	return nil
}

func fetchChatHistoryFromDb(db *sql.DB, roomId string) ([]map[string]interface{}, error) {
	query := "SELECT message FROM messages WHERE room_id = $1 ORDER BY sent_at ASD = ?"
	rows, err := db.Query(query, roomId)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var chatHistory []map[string]interface{}
	for rows.Next() {
		var fromId, message string
		err := rows.Scan(&fromId, &message)
		if err != nil {
			return nil, err
		}
		chatHistory = append(chatHistory, map[string]interface{}{
			"sender_id": fromId,
			"message":   message,
		})
	}
	return chatHistory, nil
}

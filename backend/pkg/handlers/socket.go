package handlers

import (
	"database/sql"
	"fmt"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
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
			return fmt.Errorf("unauthorized access")
		}

		token := extractJWTFromCookieHeader(cookieHeader)

		userId, _, err := middleware.ValidateJWT(db, token)
		if err != nil {
			return fmt.Errorf("unauthorized access")
		}

		s.SetContext(userId)

		userConnections.Lock()
		userConnections.connections[userId] = s
		userConnections.Unlock()

		friendRequests, err := getRequests(db, userId)
		if err != nil {
			s.Emit("error", "unable to fetch friend requests")
			fmt.Printf("error fetching friend requests for user %s: %v\n", userId, err)
			return err
		}

		s.Emit("friendRequests", friendRequests)

		hasUnreadMessages, err := checkUnreadMessages(db, userId)
		if err != nil {
			s.Emit("error", "unable to fetch unread messages")
			fmt.Printf("error fetching unread messages for user %s: %v\n", userId, err)
			return err
		}

		s.Emit("check_unread_messages", hasUnreadMessages)

		rooms, err := getUserRooms(db, userId)
		if err != nil {
			s.Emit("error", "unable to fetch user rooms")
			fmt.Printf("error fetching rooms for user %s: %v\n", userId, err)
			return err
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
			s.Emit("error", "invalid request parameters")
			return
		}

		err := saveRequest(db, fromId, toId)
		if err != nil {
			s.Emit("error", "unable to process friend request")
			fmt.Printf("error saving friend request from %s to %s: %v\n", fromId, toId, err)
			return
		}

		friendRequests, err := getRequests(db, toId)
		if err != nil {
			fmt.Printf("error fetching friend requests for user %s: %v\n", toId, err)
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
			s.Emit("error", "invalid request parameters")
			return
		}

		err := saveAcceptance(db, fromId, toId)
		if err != nil {
			s.Emit("error", "unable to process acceptance")
			fmt.Printf("error saving acceptance from %s to %s: %v\n", fromId, toId, err)
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
			s.Emit("error", "invalid request parameters")
			return
		}

		err := saveDecline(db, fromId, toId)
		if err != nil {
			s.Emit("error", "unable to process decline")
			fmt.Printf("error declining request from %s to %s: %v\n", fromId, toId, err)
			return
		}
	})

	server.OnEvent("/", "reject_recommendation", func(s socketio.Conn, msg map[string]interface{}) {
		toId := s.Context().(string)
		fromId, ok := msg["from_id"].(string)
		if !ok {
			s.Emit("error", "invalid request parameters")
			return
		}

		err := saveRejection(db, fromId, toId)
		if err != nil {
			s.Emit("error", "unable to process recommendation rejection")
			fmt.Printf("error rejecting recommendation from %s to %s: %v\n", fromId, toId, err)
			return
		}

		s.Emit("recommendation_update_notification", true)

	})

	server.OnEvent("/", "create_room", func(s socketio.Conn, msg map[string]interface{}) {
		fromId := s.Context().(string)
		toId, ok := msg["to_id"].(string)
		if !ok {
			s.Emit("error", "invalid request parameters")
			return
		}

		roomId, err := createRoom(db, fromId, toId)
		if err != nil {
			s.Emit("error", "unable to create room")
			fmt.Printf("error creating room for users %s and %s: %v\n", fromId, toId, err)
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
			s.Emit("error", "invalid request parameters")
			return
		}
		message, ok := msg["message"].(string)
		if !ok {
			s.Emit("error", "invalid request parameters")
			return
		}
		if len([]byte(message)) > 255 {
			s.Emit("error", "Message is too long")
			return
		}

		toId, ok := msg["to_id"].(string)
		if !ok {
			s.Emit("error", "invalid request parameters")
			return
		}
		var sentAt time.Time
		messageId, err := saveMessage(db, roomId, fromId, toId, message, sentAt)
		if err != nil {
			s.Emit("error", "unable to send message")
			return
		}

		userConnections.RLock()
		receiverConn, exists := userConnections.connections[toId]
		userConnections.RUnlock()

		if exists {
			chatList, err := getChatList(db, toId)
			if err != nil {
				receiverConn.Emit("error", "unable to fetch chat list")
				fmt.Printf("error fetching chat list for user %s: %v\n", toId, err)
				return
			}
			receiverConn.Emit("get_chat_list", chatList)
		}

		server.BroadcastToRoom("/", roomId, "new_message", models.Message{
			Id:      messageId,
			RoomId:  roomId,
			FromId:  fromId,
			ToId:    toId,
			Message: message,
			SentAt:  time.Now(),
		})
	})

	server.OnEvent("/", "get_messages", func(s socketio.Conn, msg map[string]interface{}) {
		userId := s.Context().(string)
		roomId, ok := msg["room_id"].(string)
		if !ok {
			s.Emit("error", "Invalid request parameters")
			return
		}
		lastMessageId, ok := msg["last_message_id"].(int)
		if !ok {
			s.Emit("error", "Invalid request parameters")
			return
		}

		messages, err := getMessagesForRoom(db, roomId, userId, lastMessageId)
		if err != nil {
			s.Emit("error", "unable to fetch messages")
			fmt.Printf("error fetching messages for room %s and user %s: %v\n", roomId, userId, err)
			return
		}

		err = markMessagesAsRead(db, userId, roomId)
		if err != nil {
			s.Emit("error", "unable to mark messages as read")
			fmt.Printf("error marking messages as read for room %s and user %s: %v\n", roomId, userId, err)
			return
		}

		chatList, err := getChatList(db, userId)
		if err != nil {
			s.Emit("error", "unable to fetch chat list")
			fmt.Printf("error fetching chat list for user %s: %v\n", userId, err)
			return
		}
		s.Emit("get_chat_list", chatList)

		s.Emit("room_messages", messages)
	})

	server.OnEvent("/", "check_unread_message", func(s socketio.Conn) {
		userId := s.Context().(string)
		hasUnreadMessages, err := checkUnreadMessages(db, userId)
		if err != nil {
			s.Emit("error", "unable to check unread messages")
			fmt.Printf("error checking unread messages for user %s: %v\n", userId, err)
			return
		}
		s.Emit("check_unread_message", hasUnreadMessages)
	})

	server.OnEvent("/", "get_chat_list", func(s socketio.Conn) {
		userId := s.Context().(string)
		chatList, err := getChatList(db, userId)
		if err != nil {
			s.Emit("error", "unable to fetch chat list")
			fmt.Printf("error fetching chat list for user %s: %v\n", userId, err)
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

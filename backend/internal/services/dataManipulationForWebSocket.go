package services

import (
	"database/sql"
	"fmt"
	"matchMe/internal/models"
	"matchMe/pkg/utils"
	"strconv"
)

func GetConnectedUsers(db *sql.DB, userId string) ([]string, error) {
	query := `
	SELECT user_id2
	FROM connections 
	WHERE user_id1 = $1
	UNION 
	SELECT user_id1
	FROM connections 
	WHERE user_id2 = $1
	`
	rows, err := db.Query(query, userId)
	if err != nil {
		return []string{}, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		err := rows.Scan(&id)
		if err != nil {
			return []string{}, fmt.Errorf("failed to scan row: %v", err)
		}
		ids = append(ids, id)
	}

	if err = rows.Err(); err != nil {
		return []string{}, fmt.Errorf("error iterating rows: %v", err)
	}

	return ids, nil
}

func GetRequests(db *sql.DB, userId string) (models.IdList, error) {
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

func HasUnreadMessages(db *sql.DB, userId string) (bool, error) {
	query := `
	SELECT EXISTS (SELECT 1 FROM messages WHERE to_id = $1 AND read = FALSE AND to_id_connected = TRUE)
	`

	var exists bool
	err := db.QueryRow(query, userId).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check unread messages: %v", err)
	}

	return exists, nil
}

func GetNewConnections(db *sql.DB, userId string) (models.IdList, error) {

	query := `
	SELECT 
		user_id2 AS connected_user 
	FROM connections 
	WHERE user_id1 = $1 AND id1_check = FALSE 
	UNION 
	SELECT 
		user_id1 FROM connections 
	WHERE user_id2 = $1 AND id2_check = FALSE
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

func GetUserRooms(db *sql.DB, userId string) ([]string, error) {
	rows, err := db.Query("SELECT id FROM rooms WHERE (user_id1 = $1 AND user1_connected = TRUE) OR (user_id2 = $1 AND user2_connected = TRUE)", userId)
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

func SaveRequest(db *sql.DB, fromId, toId string) (bool, bool, error) {
	var previousRequest bool
	query := `SELECT EXISTS (SELECT 1 FROM requests WHERE from_id = $1 AND to_id = $2)`
	err := db.QueryRow(query, toId, fromId).Scan(&previousRequest)
	if err != nil {
		return false, true, fmt.Errorf("failed to execute query: %v", err)
	}

	var processed bool
	query = `SELECT EXISTS (SELECT 1 FROM requests WHERE from_id = $1 AND to_id = $2)`
	err = db.QueryRow(query, fromId, toId).Scan(&processed)
	if err != nil {
		return false, true, fmt.Errorf("failed to execute query: %v", err)
	}

	if previousRequest && !processed {
		_, err = db.Exec("UPDATE requests SET processed = TRUE, accepted = TRUE WHERE from_id = $1 AND to_id = $2", toId, fromId)
		if err != nil {
			return true, false, fmt.Errorf("failed to update data: %v", err)
		}

		numToId, err := strconv.Atoi(toId)
		if err != nil {
			return true, false, fmt.Errorf("failed to change string to int: %v", err)
		}

		numFromId, err := strconv.Atoi(fromId)
		if err != nil {
			return true, false, fmt.Errorf("failed to change string to int: %v", err)
		}

		smallId, largeId := utils.OrderPair(numToId, numFromId)

		_, err = db.Exec("INSERT INTO connections (user_id1, user_id2) VALUES ($1, $2) ON CONFLICT (user_id1, user_id2) DO NOTHING", smallId, largeId)
		if err != nil {
			return true, false, fmt.Errorf("failed to insert data: %v", err)
		}

	} else if !previousRequest && !processed {
		_, err = db.Exec("INSERT INTO requests (from_id, to_id) VALUES ($1, $2)", fromId, toId)
		if err != nil {
			return false, false, fmt.Errorf("failed to execute query: %v", err)
		}

		_, err = db.Exec("UPDATE matches SET requested = TRUE WHERE (user_id1 = $1 AND user_id2 = $2) OR (user_id1 = $2 AND user_id2 = $1)", fromId, toId)
		if err != nil {
			return false, false, fmt.Errorf("failed to execute query: %v", err)
		}
	}

	return previousRequest, processed, nil
}

func SaveAcceptance(db *sql.DB, fromId, toId string) error {
	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numToId, numFromId)

	_, err = db.Exec("INSERT INTO connections (user_id1, user_id2) VALUES ($1, $2) ON CONFLICT (user_id1, user_id2) DO NOTHING", smallId, largeId)
	if err != nil {
		return fmt.Errorf("failed to insert data: %v", err)
	}

	_, err = db.Exec("UPDATE requests SET processed = TRUE, accepted = TRUE WHERE from_id = $1 AND to_id = $2", fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	return nil
}

func SaveDecline(db *sql.DB, fromId, toId string) error {
	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numToId, numFromId)

	_, err = db.Exec("UPDATE requests SET processed = TRUE, accepted = FALSE WHERE from_id = $1 AND to_id = $2", fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	_, err = db.Exec("UPDATE matches SET rejected = TRUE WHERE user_id1 = $1 AND user_id2 = $2", smallId, largeId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	_, err = db.Exec("DELETE FROM connections WHERE user_id1 = $1 AND user_id2 = $2", smallId, largeId)
	if err != nil {
		return fmt.Errorf("failed to delete data: %v", err)
	}

	query := `
	UPDATE rooms 
	SET user1_connected = CASE
			WHEN user_id1 = $1 AND user_id2 = $2 THEN FALSE
			ELSE user1_connected
	END,
	user2_connected = CASE
			WHEN user_id1 = $2 AND user_id2 = $1 THEN FALSE
			ELSE user2_connected
	END
	WHERE (user_id1 = $1 AND user_id2 = $2) OR (user_id1 = $2 AND user_id2 = $1)
	`
	_, err = db.Exec(query, fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to delete data: %v", err)
	}

	return nil
}

func SaveRejection(db *sql.DB, fromId, toId string) error {

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numToId, numFromId)

	query := "UPDATE matches SET rejected = TRUE WHERE user_id1 = $1 AND user_id2 = $2"
	_, err = db.Exec(query, smallId, largeId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	query = `
	UPDATE requests 
	SET processed = TRUE, accepted = FALSE
	WHERE (
	(from_id = $1 AND to_id = $2) 
	OR 
	(from_id = $2 AND to_id = $1))
	`
	_, err = db.Exec(query, fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	return nil
}

func SaveCheckedNewConnection(db *sql.DB, userId, checkedId string) error {
	numUserId, err := strconv.Atoi(userId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}
	numCheckedId, err := strconv.Atoi(checkedId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numUserId, numCheckedId)

	if numUserId == smallId {
		_, err = db.Exec("UPDATE connections SET id1_check = TRUE WHERE user_id1 = $1 AND user_id2 = $2", smallId, largeId)
		if err != nil {
			return fmt.Errorf("failed to update data: %v", err)
		}
	} else if numUserId == largeId {
		_, err = db.Exec("UPDATE connections SET id2_check = TRUE WHERE user_id1 = $1 AND user_id2 = $2", smallId, largeId)
		if err != nil {
			return fmt.Errorf("failed to update data: %v", err)
		}
	}

	return nil
}

func CreateRoom(db *sql.DB, fromId, toId string) (string, error) {
	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return "", fmt.Errorf("failed to change string to int: %v", err)
	}
	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return "", fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numFromId, numToId)

	var roomId string
	query := `
		INSERT INTO rooms (user_id1, user_id2) VALUES ($1, $2) 
		ON CONFLICT (user_id1, user_id2) 
		DO NOTHING 
		RETURNING id
		`
	err = db.QueryRow(query, smallId, largeId).Scan(&roomId)

	if err != nil {
		return "", fmt.Errorf("failed to insert data: %v", err)
	}

	return roomId, nil
}

func SaveLeaveRoom(db *sql.DB, userId, roomId string) error {
	query := `
	UPDATE rooms 
	SET 
		user1_connected = CASE WHEN user_id1 = $1 THEN FALSE ELSE user1_connected END,
		user2_connected = CASE WHEN user_id2 = $1 THEN FALSE ELSE user2_connected END
	WHERE id = $2
	`
	_, err := db.Exec(query, userId, roomId)
	if err != nil {
		return fmt.Errorf("failed to delete data: %v", err)
	}

	return nil
}

func CanGetMessagesUsingIds(db *sql.DB, fromId, toId string) (bool, error) {
	query := `
	SELECT EXISTS (
		SELECT 1 
		FROM rooms 
		WHERE (user_id1 = $1 AND user_id2 = $2 AND user2_connected = TRUE)
		OR (user_id1 = $2 AND user_id2 = $1 AND user1_connected = TRUE)
		)
	`
	var exists bool
	err := db.QueryRow(query, fromId, toId).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to execute query: %v", err)
	}

	return exists, nil
}

func CanGetMessagesUsingRoomId(db *sql.DB, roomId, userId string) (bool, error) {
	query := `
	SELECT EXISTS (
		SELECT 1 
		FROM rooms 
		WHERE id = $1 
		AND ((user_id1 = $2 AND user1_connected = TRUE) OR (user_id2 = $2 AND user2_connected = TRUE))
		)
	`
	var exists bool
	err := db.QueryRow(query, roomId, userId).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to execute query: %v", err)
	}

	return exists, nil
}

func SaveMessage(db *sql.DB, messageInfo *models.Message) (int, error) {

	query := `SELECT id FROM rooms WHERE (user_id1 = $1 AND user_id2 = $2) OR (user_id1 = $2 AND user_id2 = $1)`
	err := db.QueryRow(query, messageInfo.FromId, messageInfo.ToId).Scan(&messageInfo.RoomId)
	if err != nil {
		return 0, fmt.Errorf("failed to execute query: %v", err)
	}

	var messageId int
	err = db.QueryRow("INSERT INTO messages (room_id, from_id, to_id, message, to_id_connected) VALUES ($1, $2, $3, $4, $5) RETURNING id", messageInfo.RoomId, messageInfo.FromId, messageInfo.ToId, messageInfo.Message, messageInfo.CanGetMessages).Scan(&messageId)
	if err != nil {
		return 0, fmt.Errorf("failed to save message: %v", err)
	}

	return messageId, nil
}

func GetChatList(db *sql.DB, userId string) ([]models.ChatList, error) {
	query := `
	SELECT
		r.id AS room_id,
		EXISTS (
			SELECT 1
			FROM messages sub
			WHERE sub.room_id = r.id AND sub.read = FALSE AND sub.to_id = $1
		) AS has_unread,
		CASE
			WHEN r.user_id1 = $1 THEN r.user_id2
			WHEN r.user_id2 = $1 THEN r.user_id1
		END AS user_id,
		COALESCE(MAX(m.sent_at), r.created_at) AS last_activity
	FROM rooms r
	LEFT JOIN messages m ON r.id = m.room_id
	WHERE (r.user_id1 = $1 AND r.user1_connected = TRUE)
     OR (r.user_id2 = $1 AND r.user2_connected = TRUE)
	GROUP BY r.id, r.user_id1, r.user_id2, r.created_at
	ORDER BY last_activity DESC;
	`

	rows, err := db.Query(query, userId)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer rows.Close()

	var chatList []models.ChatList
	for rows.Next() {
		var msg models.ChatList
		err := rows.Scan(&msg.RoomId, &msg.UnReadMessage, &msg.UserId, &msg.LastActivity)
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

func GetMessagesForRoom(db *sql.DB, roomId string, userId string, lastMessageId int) ([]models.Message, error) {
	limit := 10

	query := `
	SELECT 
		id, room_id, from_id, to_id, message, sent_at
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
		err := rows.Scan(&msg.Id, &msg.RoomId, &msg.FromId, &msg.ToId, &msg.Message, &msg.SentAt)
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

func MarkMessagesAsRead(db *sql.DB, userId, roomId string) error {
	_, err := db.Exec("UPDATE messages SET read = TRUE WHERE to_id = $1 AND room_id = $2", userId, roomId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	return nil

}

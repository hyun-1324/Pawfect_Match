package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"matchMe/pkg/models"
	"matchMe/pkg/utils"
	"strconv"
	"time"
)

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

func getNewConnections(db *sql.DB, userId string) (models.IdList, error) {

	query := `
	SELECT 
		user_id2 AS connected_user 
	FROM connections 
	WHERE user_id1 = $1 AND id1_check = FALSE 
	UNION 
	SELECT 
		user_id1 FROM connections 
	WHERE user_id2 = $1 AND id2_check = FALSE`

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

func getUserRooms(db *sql.DB, userId string) ([]string, error) {
	rows, err := db.Query("SELECT id FROM rooms WHERE user_id1 = $1 OR user_id2 = $1", userId)
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

func saveRequest(db *sql.DB, fromId, toId string) (bool, bool, error) {
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

func saveAcceptance(db *sql.DB, fromId, toId string) error {
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

func saveDecline(db *sql.DB, fromId, toId string) error {

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numToId, numFromId)

	query := "UPDATE requests SET processed = TRUE, accepted = FALSE WHERE from_id = $1 AND to_id = $2"
	_, err = db.Exec(query, fromId, toId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	query = "UPDATE matches SET rejected = TRUE WHERE user_id1 = $1 AND user_id2 = $2"
	_, err = db.Exec(query, smallId, largeId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	query = "DELETE FROM connections WHERE user_id1 = $1 AND user_id2 = $2"
	_, err = db.Exec(query, smallId, largeId)
	if err != nil {
		return fmt.Errorf("failed to delete data: %v", err)
	}

	return nil
}

func saveRejection(db *sql.DB, fromId, toId string) error {

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		return fmt.Errorf("failed to change string to int: %v", err)
	}

	smallId, largeId := utils.OrderPair(numToId, numFromId)

	query := "UPDATE matches SET rejected = TRUE WHERE from_id = $1 AND to_id = $2"
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

func saveCheckedNewConnection(db *sql.DB, userId, checkedId string) error {
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
		query := `UPDATE connections SET id1_check = TRUE WHERE user_id1 = $1 AND user_id2 = $2`
		_, err = db.Exec(query, smallId, largeId)
		if err != nil {
			return fmt.Errorf("failed to update data: %v", err)
		}
	} else if numUserId == largeId {
		query := `UPDATE connections SET id2_check = TRUE WHERE user_id1 = $1 AND user_id2 = $2`
		_, err = db.Exec(query, smallId, largeId)
		if err != nil {
			return fmt.Errorf("failed to update data: %v", err)
		}
	}

	return nil
}

func createRoom(db *sql.DB, fromId, toId string) (string, error) {
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
		RETURNING id`
	err = db.QueryRow(query, smallId, largeId).Scan(&roomId)

	if err != nil {
		return "", fmt.Errorf("failed to insert data: %v", err)
	}

	return roomId, nil
}

func saveMessage(db *sql.DB, roomId, fromId, toId, message string, sentAt time.Time) (int, error) {

	var messageId int
	err := db.QueryRow("INSERT INTO messages (room_id, from_id, to_id, message, sent_at) VALUES ($1, $2, $3, $4, $5) RETURNING id", roomId, fromId, toId, message, sentAt).Scan(&messageId)
	if err != nil {
		return 0, fmt.Errorf("failed to save message: %v", err)
	}

	return messageId, nil
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

func getMessagesForRoom(db *sql.DB, roomId string, userId string, lastMessageId int) ([]models.Message, error) {
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

func markMessagesAsRead(db *sql.DB, userId, roomId string) error {
	_, err := db.Exec("UPDATE messages SET read = TRUE WHERE to_id = $1 AND room_id = $2", userId, roomId)
	if err != nil {
		return fmt.Errorf("failed to update data: %v", err)
	}

	return nil

}

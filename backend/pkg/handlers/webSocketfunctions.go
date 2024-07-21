package handlers

import (
	"database/sql"
	"fmt"
	"matchMe/pkg/models"
)

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

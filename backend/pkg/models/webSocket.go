package models

import "time"

type Message struct {
	Id      int       `json:"id"`
	RoomID  string    `json:"room_id"`
	FromID  string    `json:"from_id"`
	ToID    string    `json:"to_id"`
	Message string    `json:"message"` // 255 characters
	SentAt  time.Time `json:"sent_at"`
}

type ChatList struct {
	RoomId        int  `json:"id"`
	UnReadMessage bool `json:"unReadMessage"`
}

type NewMessage struct {
	RoomId  int    `json:"room_id"`
	Message string `json:"message"`
}

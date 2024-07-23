package models

import (
	"encoding/json"
	"time"
)

type Event struct {
	Event string          `json:"event"`
	Data  json.RawMessage `json:"data"`
}

type RequestData struct {
	Id string `json:"Id"`
}

type Message struct {
	Id      int       `json:"id"`
	RoomId  string    `json:"room_id"`
	FromId  string    `json:"from_id"`
	ToId    string    `json:"to_id"`
	Message string    `json:"message"` // 255 characters
	SentAt  time.Time `json:"sent_at"`
}

type GetMessages struct {
	RoomId        string `json:"room_id"`
	LastMessageId int    `json:"last_message_id"`
}

type ChatList struct {
	RoomId        int  `json:"id"`
	UnReadMessage bool `json:"unReadMessage"`
}

type LeaveRoom struct {
	RoomId string `json:"room_id"`
}

type Typing struct {
	RoomId string `json:"room_id"`
	ToId   string `json:"to_id"`
}

type NewConnection struct {
	Id       int  `json:"id"`
	IsSender bool `json:"is_sender"`
}

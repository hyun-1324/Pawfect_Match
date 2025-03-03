package model

import (
	"html/template"
)

// User is the GraphQL model that corresponds to UserResponse
type User struct {
	ID      string `json:"id"`
	DogName string `json:"dogName"`
	Picture string `json:"picture,omitempty"`
}

// Bio is the GraphQL model that corresponds to UserBioResponse
type Bio struct {
	ID                string  `json:"id"`
	UserID            string  `json:"-"` // For database reference
	PreferredGender   string  `json:"preferredGender,omitempty"`
	PreferredNeutered bool    `json:"preferredNeutered,omitempty"`
	Gender            string  `json:"gender,omitempty"`
	Neutered          bool    `json:"neutered,omitempty"`
	Size              float32 `json:"size,omitempty"`
	EnergyLevel       string  `json:"energyLevel,omitempty"`
	FavoritePlayStyle string  `json:"favoritePlayStyle,omitempty"`
	Age               int     `json:"age,omitempty"`
	PreferredDistance int     `json:"preferredDistance,omitempty"`
	PreferredLocation string  `json:"preferredLocation,omitempty"`
}

// Profile is the GraphQL model that corresponds to UserProfileResponse
type Profile struct {
	ID      string `json:"id"`
	UserID  string `json:"-"` // For database reference
	AboutMe string `json:"aboutMe,omitempty"`
}

// Message is the GraphQL model for chat messages
type Message struct {
	ID         string `json:"id"`
	Content    string `json:"content"`
	SenderID   string `json:"senderId"`
	ReceiverID string `json:"receiverId"`
	Timestamp  string `json:"timestamp"`
}

// Helper functions to convert between REST models and GraphQL models

// FromUserResponse converts a UserResponse to a GraphQL User
func FromUserResponse(u *struct {
	Id      string
	DogName string
	Picture template.URL
}) *User {
	return &User{
		ID:      u.Id,
		DogName: u.DogName,
		Picture: string(u.Picture),
	}
}

// FromUserBioResponse converts a UserBioResponse to a GraphQL Bio
func FromUserBioResponse(b *struct {
	Id                string
	PreferredGender   string
	PreferredNeutered bool
	Gender            string
	Neutered          bool
	Size              float32
	EnergyLevel       string
	FavoritePlayStyle string
	Age               int
	PreferredDistance int
	PreferredLocation string
}) *Bio {
	return &Bio{
		ID:                b.Id,
		PreferredGender:   b.PreferredGender,
		PreferredNeutered: b.PreferredNeutered,
		Gender:            b.Gender,
		Neutered:          b.Neutered,
		Size:              b.Size,
		EnergyLevel:       b.EnergyLevel,
		FavoritePlayStyle: b.FavoritePlayStyle,
		Age:               b.Age,
		PreferredDistance: b.PreferredDistance,
		PreferredLocation: b.PreferredLocation,
	}
}

// FromUserProfileResponse converts a UserProfileResponse to a GraphQL Profile
func FromUserProfileResponse(p *struct {
	Id      string
	AboutMe string
}) *Profile {
	return &Profile{
		ID:      p.Id,
		AboutMe: p.AboutMe,
	}
}

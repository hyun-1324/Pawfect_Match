package models

import "html/template"

type User struct {
	Id       string `json:"id"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type UserResponse struct {
	Id      string       `json:"id"`
	DogName string       `json:"dog_name"`
	Picture template.URL `json:"picture"`
}

type UserProfileResponse struct {
	Id      string `json:"id"`
	AboutMe string `json:"about_me"`
}

type UserBioResponse struct {
	Id                string  `json:"id"`
	Location          string  `json:"location"`
	Gender            string  `json:"gender"`
	Neutered          bool    `json:"neutered"`
	Size              float32 `json:"size"`
	EnergyLevel       string  `json:"energy_level"`
	PlayStyle         string  `json:"play_style"`
	Age               int     `json:"age"`
	PreferredDistance int     `json:"preferred_distance"`
	PreferredGender   string  `json:"preferred_gender"`
	PreferredNeutered bool    `json:"preferred_neutered"`
}

type RecommendationResponse struct {
	Ids []int `json:"ids"`
}

type ConnectionResponse struct {
	Ids []int `json:"ids"`
}

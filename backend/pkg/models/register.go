package models

import "html/template"

type Register1 struct {
	UserName          string  `json:"user_name"`
	Email             string  `json:"email"`
	Password          string  `json:"password"`
	PetName           string  `json:"pet_name"`
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

type Register2 struct {
	AboutMe string       `json:"about_me"`
	Picture template.URL `json:"picture"`
}

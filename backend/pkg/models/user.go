package models

type User struct {
	Id       string `json:"id"`
	UserName string `json:"user_name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type UserResponse struct {
	Id               string `json:"id"`
	Name             string `json:"name"`
	ProfilePhotoLink string `json:"profile_photo_link"`
}

type UserProfileResponse struct {
	Id      string `json:"id"`
	AboutMe string `json:"about_me"`
}

type UserBioResponse struct {
	Id          string  `json:"id"`
	PetName     string  `json:"pet_name"`
	Location    string  `json:"location"`
	Gender      string  `json:"gender"`
	Neutered    bool    `json:"neutered"`
	Size        float32 `json:"size"`
	EnergyLevel string  `json:"energy_level"`
	PlayStyle   string  `json:"play_style"`
	Age         int     `json:"age"`
}

type RecommendationResponse struct {
	Ids []int `json:"ids"`
}

type ConnectionResponse struct {
	Ids []int `json:"ids"`
}

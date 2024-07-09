package models

type UserResponse struct {
	Name             string `json:"name"`
	ProfilePhotoLink string `json:"profile_photo_link"`
}

type UserProfileResponse struct {
	Profile string `json:"profile"`
}

type UserBioResponse struct {
	Bio string `json:"bio"`
}

type RecommendationResponse struct {
	IDs []int `json:"ids"`
}

type ConnectionResponse struct {
	IDs []int `json:"ids"`
}

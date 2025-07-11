package models

type Register struct {
	Id                int     `json:"userId"`
	Email             string  `json:"email"`
	PreviousPassword  string  `json:"previous_password"`
	Password          string  `json:"password"`
	ConfirmPassword   string  `json:"confirm_password"`
	AddPicture        bool    `json:"add_picture"`
	DogName           string  `json:"dog_name"`
	Gender            string  `json:"gender"` // male, female
	Neutered          bool    `json:"neutered"`
	Size              float64 `json:"size"`                // 0-100
	EnergyLevel       string  `json:"energy_level"`        // low, medium, high
	FavoritePlayStyle string  `json:"favorite_play_style"` //wrestling, lonely wolf, cheerleading, chasing, tugging, ripping, soft touch, body slamming
	Age               int     `json:"age"`                 // 0-30
	PreferredDistance int     `json:"preferred_distance"`  // 0-30
	PreferredGender   string  `json:"preferred_gender"`    // male, female, any
	PreferredNeutered bool    `json:"preferred_neutered"`
	PreferredLocation string  `json:"preferred_location"` // Live, Helsinki, Tampere, Turku, Jyväskylä, Kuopio
	AboutMe           string  `json:"about_me"`
}

type Login struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LiveLocation struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type AllowedMimeTypes map[string]bool

var AllowedMimeType = AllowedMimeTypes{
	"image/jpeg": true,
	"image/png":  true,
	"image/gif":  true,
}

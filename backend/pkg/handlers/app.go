package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
)

type App struct {
	DB *sql.DB
}

type contextKey string

const UserIDKey contextKey = "userId"

func (app *App) User(w http.ResponseWriter, r *http.Request) {
	var user models.UserResponse
	user.Id = r.PathValue("id")

	err := app.DB.QueryRow("SELECT users.dog_name, profile_pictures.file_url FROM users LEFT JOIN profile_pictures ON profile_pictures.user_id = users.id WHERE users.id = $1", user.Id).Scan(&user.DogName, &user.Picture)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(user)
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) GetProfilePicture(w http.ResponseWriter, r *http.Request) {
	userId := middleware.GetUserId(r)

	fileName := r.PathValue("fileName")

	if fileName == "" {
		http.Error(w, "invalid file name", http.StatusBadRequest)
		return
	}

	var data []byte
	var mimeType string
	err := app.DB.QueryRow("SELECT file_data, mime_type FROM profile_pictures WHERE user_id = $1 AND file_name = $2", userId, fileName).Scan(&data, &mimeType)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return

	}
	w.Header().Set("Content-Type", mimeType)
	w.Write(data)
}

func (app *App) UserProfile(w http.ResponseWriter, r *http.Request) {
	var profile models.UserProfileResponse
	profile.Id = r.PathValue("id")
	err := app.DB.QueryRow("SELECT about_me FROM users WHERE id = $1", profile.Id).Scan(&profile.AboutMe)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(profile)
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) UserBio(w http.ResponseWriter, r *http.Request) {
	var bio models.UserBioResponse
	bio.Id = r.PathValue("id")
	err := app.DB.QueryRow(`SELECT dog_gender, dog_neutered, dog_size, 
	dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, 
	preferred_gender, preferred_neutered, option FROM biographical_data JOIN locations ON locations.user_id = biographical_data.user_id WHERE biographical_data.user_id = $1`,
		bio.Id).Scan(&bio.Gender, &bio.Neutered, &bio.Size, &bio.EnergyLevel,
		&bio.FavoritePlayStyle, &bio.Age, &bio.PreferredDistance, &bio.PreferredGender, &bio.PreferredNeutered, &bio.LocationOption)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(bio)
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) GetMe(w http.ResponseWriter, r *http.Request) {
	var user models.UserResponse
	userId := middleware.GetUserId(r)
	user.Id = userId

	err := app.DB.QueryRow("SELECT users.dog_name, profile_pictures.file_url FROM users LEFT JOIN profile_pictures ON profile_pictures.user_id = users.id WHERE users.id = $1", user.Id).Scan(&user.DogName, &user.Picture)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(user)
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) GetMeProfile(w http.ResponseWriter, r *http.Request) {
	var profile models.UserProfileResponse
	userId := middleware.GetUserId(r)
	profile.Id = userId
	err := app.DB.QueryRow("SELECT about_me FROM users WHERE id = $1", profile.Id).Scan(&profile.AboutMe)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(profile)
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) GetMeBio(w http.ResponseWriter, r *http.Request) {
	var bio models.UserBioResponse
	userId := middleware.GetUserId(r)
	bio.Id = userId
	err := app.DB.QueryRow(`SELECT dog_gender, dog_neutered, dog_size, 
	dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, 
	preferred_gender, preferred_neutered FROM biographical_data WHERE user_id = $1`,
		bio.Id).Scan(&bio.Gender, &bio.Neutered, &bio.Size, &bio.EnergyLevel,
		&bio.FavoritePlayStyle, &bio.Age, &bio.PreferredDistance, &bio.PreferredGender, &bio.PreferredNeutered)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(bio)
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) Recommendations(w http.ResponseWriter, r *http.Request) {
	rows, err := app.DB.Query("SELECT id FROM recommendations LIMIT 10")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			http.Error(w, "failed to scan recommendations", http.StatusInternalServerError)
			return
		}
		ids = append(ids, id)
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(models.RecommendationResponse{Ids: ids})
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

func (app *App) Connections(w http.ResponseWriter, r *http.Request) {
	rows, err := app.DB.Query("SELECT id FROM connections")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			http.Error(w, "failed to scan connections", http.StatusInternalServerError)
			return
		}
		ids = append(ids, id)
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(models.ConnectionResponse{Ids: ids})
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
	}
}

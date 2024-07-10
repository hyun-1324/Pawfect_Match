package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
)

func (app *App) Register1(w http.ResponseWriter, r *http.Request) {

	// if r.Method == "GET" {

	// }
	userID := middleware.GetUserID(r)
	if userID != "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	var req models.Register1

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	app.DB.Exec(`INSERT INTO users (email, password, dog_name, dog_gender, dog_netured, dog_size, dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, preferred_gender, preferred_netured) 
	VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`, req.Email, req.Password, req.DogName, req.Gender, req.Neutered, req.Size, req.EnergyLevel, req.FavoritePlayStyle, req.Age, req.PreferredDistance, req.PreferredGender, req.PreferredNeutered)

	http.Redirect(w, r, "/register2", http.StatusSeeOther)
}

func (app *App) Register2(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID != "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	var req models.Register2

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
}

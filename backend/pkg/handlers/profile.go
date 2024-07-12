package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
	"strconv"
)

func (app *App) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	var req models.Register
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	userId := middleware.GetUserId(r)
	numId, err := strconv.Atoi(userId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = checkUserDataValidation(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, err = app.DB.Exec(`UPDATE users SET about_me = $1, dog_name = $2 WHERE users.id = $3`, req.AboutMe, req.DogName, numId)
	if err != nil {
		http.Error(w, "failed to update user data", http.StatusInternalServerError)
		return
	}

	query := `UPDATE biographical_data SET dog_gender = $1, dog_neutered = $2, dog_size = $3, dog_energy_level = $4, dog_favorite_play_style = $5, dog_age = $6, preferred_distance = $7, preferred_gender = $8, preferred_neutered = $9 WHERE biographical_data.user_id = $10`
	_, err = app.DB.Exec(query, req.Gender, req.Neutered, req.Size, req.EnergyLevel, req.FavoritePlayStyle, req.Age, req.PreferredDistance, req.PreferredGender, req.PreferredNeutered, numId)
	if err != nil {
		http.Error(w, "failed to update bio data", http.StatusInternalServerError)
		return
	}

	err = processProfilePictureData(r, app, req.Id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	calculateRecommendationScore(app, numId)

}

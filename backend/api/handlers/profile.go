package handlers

import (
	"encoding/json"
	"fmt"
	"matchMe/internal/middleware"
	"matchMe/internal/models"
	"matchMe/internal/services"
	"matchMe/pkg/utils"
	"net/http"
	"strconv"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	var req models.Register
	jsonData := r.FormValue("json")
	if jsonData == "" {
		utils.HandleError(w, "invalid request", http.StatusBadRequest, fmt.Errorf("missing json data"))
		return
	}

	if err := json.Unmarshal([]byte(jsonData), &req); err != nil {
		utils.HandleError(w, "failed to decode JSON", http.StatusInternalServerError, fmt.Errorf("failed to decode JSON data for registration: %v", err))
		return
	}

	userId := middleware.GetUserId(r)
	numId, err := strconv.Atoi(userId)
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to convert user ID to integer: %v", err))
		return
	}

	hashedPassword := []byte{}

	if !(req.PreviousPassword == "" && req.Password == "" && req.ConfirmPassword == "") {
		var previousHashedPassword string

		err = app.DB.QueryRow(`SELECT password FROM users WHERE id = $1`, numId).Scan(&previousHashedPassword)
		if err != nil {
			utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to get previous password: %v", err))
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(previousHashedPassword), []byte(req.PreviousPassword)); err != nil {
			utils.HandleError(w, "previous password is not correct", http.StatusBadRequest, nil)
			return
		}

		if req.Password == "" || len([]byte(req.Password)) > 60 {
			utils.HandleError(w, "invalid password", http.StatusBadRequest, nil)
			return
		}

		if req.ConfirmPassword != req.Password {
			utils.HandleError(w, "passwords do not match", http.StatusBadRequest, nil)
			return
		}

		hashedPassword, err = bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to hash password: %v", err))
			return
		}

	}

	err = checkUserDataValidation(req)
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to validate user data for updating profile: %v", err))
		return
	}

	latitude, longitude, err := checkLocationData(req.PreferredLocation)
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to validate location data for updating profile: %v", err))
		return
	}

	_, err = app.DB.Exec(`UPDATE locations set option=$1, latitude=$2, longitude=$3 WHERE user_id = $4`, req.PreferredLocation, latitude, longitude, req.Id)
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to update location data for updating profile: %v", err))
		return
	}

	if len(hashedPassword) > 0 {
		_, err = app.DB.Exec(`UPDATE users SET about_me = $1, dog_name = $2, password = $3 WHERE users.id = $4`, req.AboutMe, req.DogName, hashedPassword, numId)
		if err != nil {
			utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to update user data for updating profile: %v", err))
			return
		}
	} else {
		_, err = app.DB.Exec(`UPDATE users SET about_me = $1, dog_name = $2 WHERE users.id = $3`, req.AboutMe, req.DogName, numId)
		if err != nil {
			utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to update user data for updating profile: %v", err))
			return
		}
	}

	query := `
	UPDATE 
		biographical_data SET dog_gender = $1, dog_neutered = $2, dog_size = $3, dog_energy_level = $4, dog_favorite_play_style = $5, dog_age = $6, preferred_distance = $7, preferred_gender = $8, preferred_neutered = $9 
	WHERE biographical_data.user_id = $10`
	_, err = app.DB.Exec(query, req.Gender, req.Neutered, req.Size, req.EnergyLevel, req.FavoritePlayStyle, req.Age, req.PreferredDistance, req.PreferredGender, req.PreferredNeutered, numId)
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to update bio data for updating profile: %v", err))
		return
	}

	err = processProfilePictureData(r, app, numId, req.AddPicture)
	if err != nil {
		utils.HandleError(w, "failed to update profile picture", http.StatusInternalServerError, fmt.Errorf("failed to process profile picture data for updating profile: %v", err))
		return
	}

	err = services.CalculateRecommendationScore(app.DB, numId)
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to calculate recommendation score for updating profile: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	if err != nil {
		utils.HandleError(w, "failed to update profile", http.StatusInternalServerError, fmt.Errorf("failed to encode response for updating profile: %v", err))
		return
	}
}

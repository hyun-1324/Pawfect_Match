package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"

	"matchMe/internal/middleware"
	"matchMe/internal/models"
	"matchMe/pkg/utils"
)

func (app *App) User(w http.ResponseWriter, r *http.Request) {
	var user models.UserResponse
	userId := middleware.GetUserId(r)
	user.Id = r.PathValue("id")
	var fileURL sql.NullString

	err := app.DB.QueryRow("SELECT users.dog_name, profile_pictures.file_url FROM users LEFT JOIN profile_pictures ON profile_pictures.user_id = users.id WHERE users.id = $1", user.Id).Scan(&user.DogName, &fileURL)
	if err != nil {
		if err == sql.ErrNoRows {
			utils.HandleError(w, "failed to fetch data for user", http.StatusNotFound, fmt.Errorf("user with id %s not found", user.Id))
			return
		}
		utils.HandleError(w, "failed to fetch data for user", http.StatusNotFound, fmt.Errorf("failed to fetch data for user: %v", err))
		return
	}

	if fileURL.Valid {
		user.Picture = template.URL(fileURL.String)
	}

	err = checkRecommendationAndConnectionStatus(app.DB, userId, user.Id)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for user", http.StatusNotFound, fmt.Errorf("failed to check recommendation and connection status for user: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(user)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for user", http.StatusNotFound, fmt.Errorf("failed to encode JSON for user: %v", err))
		return
	}
}

func (app *App) GetProfilePicture(w http.ResponseWriter, r *http.Request) {
	userId := middleware.GetUserId(r)

	fileName := r.PathValue("fileName")
	if fileName == "" {
		utils.HandleError(w, "invalid file name", http.StatusBadRequest, fmt.Errorf("invalid file name"))
		return
	}

	var pictureOwner string
	var data []byte
	var mimeType string
	err := app.DB.QueryRow("SELECT user_id, file_data, file_type FROM profile_pictures WHERE file_name = $1", fileName).Scan(&pictureOwner, &data, &mimeType)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for picture", http.StatusNotFound, fmt.Errorf("failed to fetch data for profile picture: %v", err))
		return
	}

	if pictureOwner != userId {
		err = checkRecommendationAndConnectionStatus(app.DB, userId, pictureOwner)
		if err != nil {
			utils.HandleError(w, "failed to fetch data for picture", http.StatusNotFound, fmt.Errorf("failed to check recommendation and connection status for profile picture: %v", err))
			return
		}
	}

	w.Header().Set("Content-Type", mimeType)
	w.Header().Set("Cache-Control", "public, max-age=600")
	w.Write(data)
}

func (app *App) UserProfile(w http.ResponseWriter, r *http.Request) {
	var profile models.UserProfileResponse
	userId := middleware.GetUserId(r)
	profile.Id = r.PathValue("id")
	err := app.DB.QueryRow("SELECT about_me FROM users WHERE id = $1", profile.Id).Scan(&profile.AboutMe)
	if err != nil {
		if err == sql.ErrNoRows {
			utils.HandleError(w, "failed to fetch data for user profile", http.StatusNotFound, fmt.Errorf("user profile with id %s not found", profile.Id))
			return
		}
		utils.HandleError(w, "failed to fetch data for user profile", http.StatusNotFound, fmt.Errorf("failed to fetch data for user profile: %v", err))
		return
	}

	err = checkRecommendationAndConnectionStatus(app.DB, userId, profile.Id)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for user profile", http.StatusNotFound, fmt.Errorf("failed to check recommendation and connection status for user profile: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(profile)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for user profile", http.StatusNotFound, fmt.Errorf("failed to encode JSON for user profile: %v", err))
		return
	}
}

func (app *App) UserBio(w http.ResponseWriter, r *http.Request) {
	var bio models.UserBioResponse
	userId := middleware.GetUserId(r)
	bio.Id = r.PathValue("id")
	err := app.DB.QueryRow(`
	SELECT 
		dog_gender, dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, preferred_gender, preferred_neutered, option 
	FROM biographical_data JOIN locations 
	ON locations.user_id = biographical_data.user_id
	WHERE biographical_data.user_id = $1`,
		bio.Id).Scan(&bio.Gender, &bio.Neutered, &bio.Size, &bio.EnergyLevel,
		&bio.FavoritePlayStyle, &bio.Age, &bio.PreferredDistance, &bio.PreferredGender, &bio.PreferredNeutered, &bio.PreferredLocation)
	if err != nil {
		if err == sql.ErrNoRows {
			utils.HandleError(w, "failed to fetch data for user bio", http.StatusNotFound, fmt.Errorf("user bio with id %s not found", bio.Id))
			return
		}
		utils.HandleError(w, "failed to fetch data for user bio", http.StatusNotFound, fmt.Errorf("failed to fetch data for user bio: %v", err))
		return
	}

	err = checkRecommendationAndConnectionStatus(app.DB, userId, bio.Id)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for user bio", http.StatusNotFound, fmt.Errorf("failed to check recommendation and connection status for user bio: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(bio)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for user bio", http.StatusNotFound, fmt.Errorf("failed to encode JSON for user bio: %v", err))
		return
	}
}

func checkRecommendationAndConnectionStatus(db *sql.DB, userId, targetId string) error {

	query := `SELECT 
	EXISTS(
	SELECT 1
		FROM (
		SELECT user_id1, user_id2
		FROM matches
		WHERE (user_id1 = $1 OR user_id2 = $1)
		  AND compatible_neutered = true 
			AND compatible_gender = true 
			AND compatible_play_style = true 
			AND compatible_size = true 
			AND compatible_distance = true 
			AND rejected = FALSE 
			AND requested = FALSE
		ORDER BY match_score DESC 
		LIMIT 10
		) AS top_matches
	WHERE (user_id1 = $1 AND user_id2 = $2) OR (user_id1 = $2 AND user_id2 = $1)
  ) AS recommendationExists,
  EXISTS(
	SELECT 1
	  FROM connections
	  WHERE (user_id1 = $1 AND user_id2 = $2) OR (user_id1 = $2 AND user_id2 = $1)
	) AS connectionExists,
	EXISTS(
	SELECT 1
		FROM requests
		WHERE (from_id = $2 AND to_id = $1)
			AND processed = FALSE
	) AS requestExists
	`

	var recommendationExists, connectionExists, requestExists bool
	err := db.QueryRow(query, userId, targetId).Scan(&recommendationExists, &connectionExists, &requestExists)
	if err != nil {
		return err
	}

	if recommendationExists || connectionExists || requestExists {
		return nil
	} else {
		return fmt.Errorf("unauthorized access")
	}
}

func (app *App) GetMe(w http.ResponseWriter, r *http.Request) {
	var user models.UserResponse
	userId := middleware.GetUserId(r)
	user.Id = userId
	var fileURL sql.NullString

	err := app.DB.QueryRow("SELECT users.dog_name, profile_pictures.file_url FROM users LEFT JOIN profile_pictures ON profile_pictures.user_id = users.id WHERE users.id = $1", user.Id).Scan(&user.DogName, &fileURL)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for me", http.StatusNotFound, fmt.Errorf("failed to fetch data for my user info: %v", err))
		return
	}

	if fileURL.Valid {
		user.Picture = template.URL(fileURL.String)
	}

	err = json.NewEncoder(w).Encode(user)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for me", http.StatusNotFound, fmt.Errorf("failed to encode JSON for my user info: %v", err))
		return
	}
}

func (app *App) GetMeProfile(w http.ResponseWriter, r *http.Request) {
	var profile models.UserProfileResponse
	userId := middleware.GetUserId(r)
	profile.Id = userId
	err := app.DB.QueryRow("SELECT about_me FROM users WHERE id = $1", profile.Id).Scan(&profile.AboutMe)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for me", http.StatusNotFound, fmt.Errorf("failed to fetch data for my profile: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(profile)
	if err != nil {

		utils.HandleError(w, "failed to fetch data for me", http.StatusNotFound, fmt.Errorf("failed to encode JSON for my profile: %v", err))
		return
	}
}

func (app *App) GetMeBio(w http.ResponseWriter, r *http.Request) {
	var bio models.UserBioResponse
	userId := middleware.GetUserId(r)
	bio.Id = userId
	err := app.DB.QueryRow(`
	SELECT 
		dog_gender, dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, preferred_gender, preferred_neutered, preferred_location 
	FROM biographical_data 
	WHERE user_id = $1`,
		bio.Id).Scan(&bio.Gender, &bio.Neutered, &bio.Size, &bio.EnergyLevel,
		&bio.FavoritePlayStyle, &bio.Age, &bio.PreferredDistance, &bio.PreferredGender, &bio.PreferredNeutered, &bio.PreferredLocation)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for my bio", http.StatusNotFound, fmt.Errorf("failed to fetch data for my bio: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(bio)
	if err != nil {
		utils.HandleError(w, "failed to fetch data for my bio", http.StatusNotFound, fmt.Errorf("failed to encode JSON for my bio: %v", err))
		return
	}
}

func (app *App) GetRecommendations(w http.ResponseWriter, r *http.Request) {
	userId := middleware.GetUserId(r)

	query := `
	SELECT
		CASE
			WHEN user_id1 = $1 THEN user_id2
			WHEN user_id2 = $1 THEN user_id1
		END AS matched_user_id
	FROM matches
	WHERE (user_id1 = $1 OR user_id2 = $1) AND 
	compatible_neutered = true AND 
	compatible_gender = true AND
	compatible_play_style = true AND 
	compatible_size = true AND 
	compatible_distance = true AND 
	rejected = FALSE AND 
	requested = FALSE
	ORDER BY match_score DESC LIMIT 10
	`
	rows, err := app.DB.Query(query, userId)
	if err != nil {
		utils.HandleError(w, "failed to fetch recommendation data", http.StatusNotFound, fmt.Errorf("failed to fetch recommendations: %v", err))
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			utils.HandleError(w, "failed to fetch recommendation data", http.StatusNotFound, fmt.Errorf("failed to scan recommendations: %v", err))
			return
		}
		ids = append(ids, id)
	}

	err = json.NewEncoder(w).Encode(models.IdList{Ids: ids})
	if err != nil {
		utils.HandleError(w, "failed to fetch recommendation data", http.StatusNotFound, fmt.Errorf("failed to encode JSON for recommendations: %v", err))
		return
	}
}

func (app *App) GetConnections(w http.ResponseWriter, r *http.Request) {
	userId := middleware.GetUserId(r)
	query := `
	SELECT
		CASE
			WHEN user_id1 = $1 THEN user_id2
			WHEN user_id2 = $1 THEN user_id1
		END AS connectied_user_id
	FROM connections
	WHERE user_id1 = $1 OR user_id2 = $1`
	rows, err := app.DB.Query(query, userId)
	if err != nil {
		utils.HandleError(w, "failed to fetch connection data", http.StatusNotFound, fmt.Errorf("failed to fetch connections: %v", err))
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			utils.HandleError(w, "failed to fetch connection data", http.StatusNotFound, fmt.Errorf("failed to scan connections: %v", err))
			return
		}
		ids = append(ids, id)
	}

	err = json.NewEncoder(w).Encode(models.IdList{Ids: ids})
	if err != nil {
		utils.HandleError(w, "failed to fetch connection data", http.StatusNotFound, fmt.Errorf("failed to encode JSON for connections: %v", err))
		return
	}
}

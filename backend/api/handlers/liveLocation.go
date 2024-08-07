package handlers

import (
	"encoding/json"
	"fmt"
	"matchMe/internal/middleware"
	"matchMe/internal/models"
	"matchMe/pkg/utils"
	"net/http"
)

// updates the live location of the user
func (app *App) UpdateLivelocation(w http.ResponseWriter, r *http.Request) {
	var liveLoc models.LiveLocation
	userId := middleware.GetUserId(r)

	err := json.NewDecoder(r.Body).Decode(&liveLoc)
	if err != nil {
		utils.HandleError(w, "invalid request", http.StatusBadRequest, fmt.Errorf("failed to decode JSON for live location: %v", err))
		return
	}

	query := `
	INSERT INTO 
		locations (user_id, latitude, longitude, option) VALUES ($1, $2, $3, 'Live') 
	ON CONFLICT (user_id) 
	DO UPDATE 
	SET 
		latitude = EXCLUDED.latitude, 
		longitude = EXCLUDED.longitude;
	`
	_, err = app.DB.Exec(query, userId, liveLoc.Latitude, liveLoc.Longitude)
	if err != nil {
		utils.HandleError(w, "failed to insert data", http.StatusInternalServerError, fmt.Errorf("failed to insert live location data: %v", err))
		return
	}

	w.WriteHeader(http.StatusOK)
}

package handlers

import (
	"encoding/json"
	"fmt"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"matchMe/pkg/utils"
	"net/http"
)

func (app *App) UpdateLivelocation(w http.ResponseWriter, r *http.Request) {
	var liveLoc models.LiveLocation
	userId := middleware.GetUserId(r)

	err := json.NewDecoder(r.Body).Decode(&liveLoc)
	if err != nil {
		utils.HandleError(w, "invalid request", http.StatusBadRequest, fmt.Errorf("failed to decode JSON for live location: %v", err))
		return
	}

	var exists bool
	err = app.DB.QueryRow(`SELECT EXISTS(SELECT 1 FROM locations WHERE option = 'Live' AND user_id = $1)`, userId).Scan(&exists)
	if err != nil {
		utils.HandleError(w, "failed to fetch data", http.StatusInternalServerError, fmt.Errorf("failed to check if live location data is available: %v", err))
		return
	}
	if exists {
		// Insert the location of the user
		query := `INSERT INTO locations (user_id, latitude, longitude) VALUES ($1, $2, $3) ON CONFLICT (user_id) DO UPDATE SET latitude = $2, longitude = $3;`
		_, err = app.DB.Exec(query, userId, liveLoc.Latitude, liveLoc.Longitude)
		if err != nil {
			utils.HandleError(w, "failed to insert data", http.StatusInternalServerError, fmt.Errorf("failed to insert live location data: %v", err))
			return
		}
	}

	err = json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	if err != nil {
		utils.HandleError(w, "failed to update live location", http.StatusInternalServerError, fmt.Errorf("failed to encode response for live location: %v", err))
		return
	}
}

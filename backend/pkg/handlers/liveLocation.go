package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
)

func (app *App) UpdateLivelocation(w http.ResponseWriter, r *http.Request) {
	var liveLoc models.LiveLocation
	userId := middleware.GetUserId(r)

	err := json.NewDecoder(r.Body).Decode(&liveLoc)
	if err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	var exists bool
	err = app.DB.QueryRow(`SELECT EXISTS(SELECT 1 FROM locations WHERE option = "Live" AND user_id = $1`, userId).Scan(&exists)
	if err != nil {
		http.Error(w, "database error", http.StatusInternalServerError)
		return
	}
	if exists {
		// Insert the location of the user
		query := `INSERT INTO locations (user_id, latitude, longitude) VALUES ($1, $2, $3) ON CONFLICT (user_id) DO UPDATE SET latitude = $2, longitude = $3;`
		_, err = app.DB.Exec(query, userId, liveLoc.Latitude, liveLoc.Longitude)
		if err != nil {
			http.Error(w, "failed to insert location", http.StatusInternalServerError)
			return
		}
	}
}

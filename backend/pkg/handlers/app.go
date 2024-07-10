package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"

	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
)

type App struct {
	DB *sql.DB
}

func (app *App) User(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var user models.UserResponse
	err := app.DB.QueryRow("SELECT name, profile_photo_link FROM users WHERE id = $1", userID).Scan(&user.Name, &user.ProfilePhotoLink)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

func (app *App) UserProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var profile models.UserProfileResponse
	err := app.DB.QueryRow("SELECT profile FROM users WHERE id = $1", userID).Scan(&profile.AboutMe)
	if err != nil {
		http.Error(w, "Profile not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(profile)
}

func (app *App) UserBio(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var bio models.UserBioResponse
	err := app.DB.QueryRow("SELECT bio FROM users WHERE id = $1", userID).Scan(&bio.Location)
	if err != nil {
		http.Error(w, "Bio not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(bio)
}

func (app *App) GetMe(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	r = r.WithContext(context.WithValue(r.Context(), "userID", userID))
	app.User(w, r)

}

func (app *App) GetMeProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	r = r.WithContext(context.WithValue(r.Context(), "userID", userID))
	app.UserProfile(w, r)
}

func (app *App) GetMeBio(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	r = r.WithContext(context.WithValue(r.Context(), "userID", userID))
	app.UserBio(w, r)
}

func (app *App) Recommendations(w http.ResponseWriter, r *http.Request) {
	rows, err := app.DB.Query("SELECT id FROM recommendations LIMIT 10")
	if err != nil {
		http.Error(w, "Failed to fetch recommendations", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			http.Error(w, "Failed to scan recommendations", http.StatusInternalServerError)
			return
		}
		ids = append(ids, id)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.RecommendationResponse{IDs: ids})
}

func (app *App) Connections(w http.ResponseWriter, r *http.Request) {
	rows, err := app.DB.Query("SELECT id FROM connections")
	if err != nil {
		http.Error(w, "Failed to fetch connections", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			http.Error(w, "Failed to scan connections", http.StatusInternalServerError)
			return
		}
		ids = append(ids, id)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.ConnectionResponse{IDs: ids})
}

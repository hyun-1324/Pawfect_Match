package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
)

func (app *App) Register1(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID != "" {
		http.Redirect(w, r, "/recommendations", http.StatusSeeOther)
		return
	}

	var req models.Register1

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

}

func (app *App) Register2(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID != "" {
		http.Redirect(w, r, "/recommendations", http.StatusSeeOther)
		return
	}

	var req models.Register2

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
}

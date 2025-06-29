package handlers

import (
	"fmt"
	"matchMe/internal/middleware"
	"matchMe/pkg/utils"
	"net/http"
)

// check if the user is logged in
func (app *App) CheckLoginStatus(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("jwt_token")
	if err != nil {
		if err == http.ErrNoCookie {
			w.WriteHeader(http.StatusOK)
			return
		}
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, fmt.Errorf("failed to get JWT token when checking login status: %v", err))
		return
	}

	blacklisted, err := middleware.CheckBlacklist(app.DB, cookie.Value)
	if err != nil {
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, fmt.Errorf("failed to check blacklist when checking login status: %v", err))
		return
	}

	if blacklisted {
		w.WriteHeader(http.StatusOK)
		return
	}

	_, _, err = middleware.ValidateJWT(app.DB, cookie.Value)
	if err != nil {
		w.WriteHeader(http.StatusOK)
		return
	}

	utils.HandleError(w, "already logged in", http.StatusBadRequest, nil)
}

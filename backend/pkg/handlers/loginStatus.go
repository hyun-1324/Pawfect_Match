package handlers

import (
	"encoding/json"
	"fmt"
	"matchMe/pkg/middleware"
	"matchMe/pkg/utils"
	"net/http"
)

func (app *App) CheckLoginStatus(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("jwt_token")
	if err != nil {
		if err == http.ErrNoCookie {
			utils.HandleError(w, "unauthorized access", http.StatusUnauthorized, fmt.Errorf("JWT token not found when checking login status: %v", err))
			return
		}
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, fmt.Errorf("failed to get JWT token when checking login status: %v", err))
		return
	}

	_, _, err = middleware.ValidateJWT(app.DB, cookie.Value)
	if err != nil {
		utils.HandleError(w, "unauthorized access", http.StatusUnauthorized, fmt.Errorf("failed to validate JWT token when checking login status: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	if err != nil {
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, fmt.Errorf("failed to encode response when checking login status: %v", err))
		return
	}

}

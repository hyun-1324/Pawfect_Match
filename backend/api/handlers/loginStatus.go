package handlers

import (
	"encoding/json"
	"fmt"
	"matchMe/internal/middleware"
	"matchMe/pkg/utils"
	"net/http"
)

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
		utils.HandleError(w, "", http.StatusOK, nil)
		return
	}

	_, _, err = middleware.ValidateJWT(app.DB, cookie.Value)
	if err != nil {
		if err.Error() == "token expired" {
			utils.HandleError(w, "", http.StatusOK, nil)
			return
		}
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, fmt.Errorf("failed to validate JWT token when checking login status: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	if err != nil {
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, fmt.Errorf("failed to encode response when checking login status: %v", err))
		return
	}

}

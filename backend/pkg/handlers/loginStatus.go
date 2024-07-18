package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/utils"
	"net/http"
)

func (app *App) CheckLoginStatus(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("jwt_token")
	if err != nil {
		if err == http.ErrNoCookie {
			utils.HandleError(w, "unauthorized access", http.StatusUnauthorized, err)
			return
		}
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, err)
		return
	}

	_, _, err = middleware.ValidateJWT(app.DB, cookie.Value)
	if err != nil {
		utils.HandleError(w, "unauthorized access", http.StatusUnauthorized, err)
		return
	}

	err = json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	if err != nil {
		utils.HandleError(w, "failed to check login status", http.StatusInternalServerError, err)
		return
	}

}

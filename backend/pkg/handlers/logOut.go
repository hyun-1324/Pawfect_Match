package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/util"
	"net/http"
)

func (app *App) Logout(w http.ResponseWriter, r *http.Request) {
	// Get the JWT token from the request
	cookie, err := r.Cookie("jwt_token")
	if err != nil {
		util.HandleError(w, "failed to get JWT token", http.StatusBadRequest, err)
		return
	}

	// Add the JWT token to the blacklist
	err = middleware.AddTokenToBlacklist(app.DB, cookie.Value)
	if err != nil {
		util.HandleError(w, "failed to logout", http.StatusInternalServerError, err)
		return
	}

	// Delete the JWT token cookie
	http.SetCookie(w, &http.Cookie{
		Name:   "jwt_token",
		Value:  "",
		MaxAge: -1,
		Path:   "/",
	})

	response := map[string]string{"Message": "Logout successful"}
	responseJSON, err := json.Marshal(response)
	if err != nil {
		util.HandleError(w, "failed to create response", http.StatusInternalServerError, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(responseJSON)
}

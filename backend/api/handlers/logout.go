package handlers

import (
	"fmt"
	"matchMe/internal/middleware"
	"matchMe/pkg/utils"
	"net/http"
)

func (app *App) Logout(w http.ResponseWriter, r *http.Request) {
	// Get the JWT token from the request
	cookie, err := r.Cookie("jwt_token")
	if err != nil {
		if err == http.ErrNoCookie {
			utils.HandleError(w, "unauthorized access", http.StatusUnauthorized, fmt.Errorf("JWT token not found when logging out: %v", err))
			return
		}
		utils.HandleError(w, "failed to get JWT token", http.StatusBadRequest, fmt.Errorf("failed to get JWT token when logging out: %v", err))
		return
	}

	userId := middleware.GetUserId(r)

	app.unregisterClientFromLogout(userId)

	// Add the JWT token to the blacklist
	err = middleware.AddTokenToBlacklist(app.DB, cookie.Value)
	if err != nil {
		utils.HandleError(w, "failed to logout", http.StatusInternalServerError, fmt.Errorf("failed to add token to blacklist: %v", err))
		return
	}

	// Delete the JWT token cookie
	http.SetCookie(w, &http.Cookie{
		Name:   "jwt_token",
		Value:  "",
		MaxAge: -1,
		Path:   "/",
	})

	w.WriteHeader(http.StatusOK)
}

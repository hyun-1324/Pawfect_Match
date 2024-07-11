package handlers

import (
	"matchMe/pkg/middleware"
	"net/http"
)

func (app *App) Logout(w http.ResponseWriter, r *http.Request) {
	// Get the JWT token from the request
	cookie, err := r.Cookie("jwt_token")
	if err != nil {
		http.Error(w, "failed to get JWT token", http.StatusInternalServerError)
		return
	}

	// Add the JWT token to the blacklist
	err = middleware.AddTokenToBlacklist(app.DB, cookie.Value)
	if err != nil {
		http.Error(w, "failed to add token to blacklist", http.StatusInternalServerError)
		return
	}

	// Delete the JWT token cookie
	http.SetCookie(w, &http.Cookie{
		Name:   "jwt_token",
		Value:  "",
		MaxAge: -1,
		Path:   "/",
	})

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

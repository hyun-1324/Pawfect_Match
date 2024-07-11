package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) Login(w http.ResponseWriter, r *http.Request) {
	var loginInfo models.Login

	if err := json.NewDecoder(r.Body).Decode(&loginInfo); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	err := ValidateEmailData(loginInfo.Email)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if loginInfo.Password == "" || len([]byte(loginInfo.Password)) > 60 {
		http.Error(w, "invalid password", http.StatusBadRequest)
		return
	}

	// Check if the user exists in the database
	var userId string
	var hashedPassword string
	query := "SELECT id, password FROM users WHERE email = ?"
	err = app.DB.QueryRow(query, loginInfo.Email).Scan(&userId, &hashedPassword)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	// Check if the password is correct
	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(loginInfo.Password)); err != nil {
		http.Error(w, "Invalid password", http.StatusUnauthorized)
		return
	}

	// Generate a JWT token
	token, err := middleware.GenerateJWT(userId)
	if err != nil {
		http.Error(w, "failed to generate JWT token", http.StatusInternalServerError)
		return
	}

	// Set the JWT token as a cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "jwt_token",
		Value:    token,
		Expires:  time.Now().Add(1 * time.Hour),
		HttpOnly: true,
		Secure:   true,
		Path:     "/",
	})

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

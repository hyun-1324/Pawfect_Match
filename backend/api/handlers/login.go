package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"matchMe/internal/middleware"
	"matchMe/internal/models"
	"matchMe/pkg/utils"
	"net/http"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) Login(w http.ResponseWriter, r *http.Request) {
	var loginInfo models.Login

	err := json.NewDecoder(r.Body).Decode(&loginInfo)
	if err != nil {
		utils.HandleError(w, "invalid request", http.StatusBadRequest, fmt.Errorf("failed to decode JSON for login: %v", err))
		return
	}

	err = validateEmailData(loginInfo.Email)
	if err != nil {
		utils.HandleError(w, "invalid email", http.StatusBadRequest, fmt.Errorf("failed to validate email: %v", err))
		return
	}

	if loginInfo.Password == "" || len([]byte(loginInfo.Password)) > 60 {
		utils.HandleError(w, "invalid password", http.StatusBadRequest, nil)
		return
	}

	// Check if the user exists in the database
	var userId string
	var hashedPassword string
	query := "SELECT id, password FROM users WHERE email = $1"
	err = app.DB.QueryRow(query, loginInfo.Email).Scan(&userId, &hashedPassword)
	if err != nil {
		if err == sql.ErrNoRows {
			utils.HandleError(w, "e-mail or password is not correct", http.StatusBadRequest, nil)
			return
		}
		utils.HandleError(w, "", http.StatusInternalServerError, fmt.Errorf("failed to check if user exists during login process: %v", err))
		return
	}

	// Check if the password is correct
	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(loginInfo.Password)); err != nil {
		utils.HandleError(w, "e-mail or password is not correct", http.StatusBadRequest, nil)
		return
	}

	// Generate a JWT token
	token, err := middleware.GenerateJWT(userId)
	if err != nil {
		utils.HandleError(w, "failed to authenticate the user", http.StatusInternalServerError, fmt.Errorf("failed to generate JWT token: %v", err))
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
		SameSite: http.SameSiteStrictMode,
	})

	w.WriteHeader(http.StatusOK)
}

package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"matchMe/pkg/util"
	"net/http"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) Login(w http.ResponseWriter, r *http.Request) {
	var loginInfo models.Login

	err := json.NewDecoder(r.Body).Decode(&loginInfo)
	if err != nil {
		util.HandleError(w, "invalid request", http.StatusBadRequest, err)
		return
	}

	err = validateEmailData(loginInfo.Email)
	if err != nil {
		util.HandleError(w, "invalid email", http.StatusBadRequest, err)
		return
	}

	if loginInfo.Password == "" || len([]byte(loginInfo.Password)) > 60 {
		util.HandleError(w, "invalid password", http.StatusBadRequest, err)
		return
	}

	// Check if the user exists in the database
	var userId string
	var hashedPassword string
	query := "SELECT id, password FROM users WHERE email = $1"
	err = app.DB.QueryRow(query, loginInfo.Email).Scan(&userId, &hashedPassword)
	if err != nil {
		util.HandleError(w, "e-mail or password is not correct", http.StatusBadRequest, err)
		return
	}

	// Check if the password is correct
	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(loginInfo.Password)); err != nil {
		util.HandleError(w, "e-mail or password is not correct", http.StatusBadRequest, err)
		return
	}

	// Generate a JWT token
	token, err := middleware.GenerateJWT(userId)
	if err != nil {
		util.HandleError(w, "failed to authenticate the user", http.StatusInternalServerError, err)
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

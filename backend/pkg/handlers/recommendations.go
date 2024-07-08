package handlers

import (
	"database/sql"
	"fmt"
	"net/http"
)

type App struct {
	DB *sql.DB
}

func (app *App) Recommendation(w http.ResponseWriter, r *http.Request) {
	// Get the user ID from the request
	userID := r.Context().Value("userID").(int)

	fmt.Println(userID)

}

package handlers

import (
	"fmt"
	"net/http"
)

func (app *App) RecommendationPage(w http.ResponseWriter, r *http.Request) {
	// Get the user ID from the request
	userID := r.Context().Value("userID").(int)

	fmt.Println(userID)

}

package main

import (
	"fmt"
	"log"
	"matchMe/pkg/db"
	"matchMe/pkg/handlers"
	"matchMe/pkg/middleware"
	"net/http"

	"github.com/rs/cors"
)

func main() {
	const (
		dbname   = "matchme"
		user     = "veera"
		password = "a"
		host     = "localhost"
		port     = 5432
	)

	psqlInfo := fmt.Sprintf("dbname=%s user=%s password=%s host=%s port=%d sslmode=disable", dbname, user, password, host, port)
	database, err := db.InitDb(psqlInfo)
	if err != nil {
		log.Fatalf("Error initializing database: %v", err)
	}
	defer database.Close()

	app := &handlers.App{
		DB: database,
	}

	corsMiddleware := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})

	http.Handle("/ws", middleware.AuthMiddleware(database, http.HandlerFunc(app.HandleConnections)))

	http.Handle("GET /users/{id}", middleware.AuthMiddleware(database, http.HandlerFunc(app.User)))
	http.Handle("GET /users/{id}/profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.UserProfile)))
	http.Handle("GET /users/{id}/bio", middleware.AuthMiddleware(database, http.HandlerFunc(app.UserBio)))
	http.Handle("GET /profile_pictures/{fileName}", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetProfilePicture)))
	http.Handle("GET /me", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetMe)))
	http.Handle("GET /me/profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetMeProfile)))
	http.Handle("GET /me/bio", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetMeBio)))
	http.Handle("GET /recommendations", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetRecommendations)))
	http.Handle("GET /connections", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetConnections)))
	http.Handle("POST /handle_live", middleware.AuthMiddleware(database, http.HandlerFunc(app.UpdateLivelocation)))
	http.Handle("POST /handle_profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.UpdateProfile)))
	http.Handle("GET /handle_logout", middleware.AuthMiddleware(database, http.HandlerFunc(app.Logout)))
	http.Handle("GET /login_status", http.HandlerFunc(app.CheckLoginStatus))
	http.Handle("POST /handle_login", http.HandlerFunc(app.Login))
	http.Handle("POST /handle_register", http.HandlerFunc(app.Register))

	handler := corsMiddleware.Handler(http.DefaultServeMux)

	log.Println("Staring server on port 8080...")
	if err := http.ListenAndServe(":8080", handler); err != nil {
		log.Fatal(err)
	}
}

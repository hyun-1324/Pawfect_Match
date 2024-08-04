package main

import (
	"fmt"
	"log"
	"matchMe/api/handlers"
	"matchMe/internal/database"
	"matchMe/internal/middleware"
	"net/http"

	"github.com/rs/cors"
)

func main() {
	const (
		host     = "postgres"
		port     = 5432
		dbname   = "postgres"
		user     = "postgres"
		password = "matchMe"
	)

	psqlInfo := fmt.Sprintf("postgres://%v:%v@%v:%v/%v?sslmode=disable", user, password, host, port, dbname)
	database, err := database.InitDb(psqlInfo)
	if err != nil {
		log.Fatalf("Error initializing database: %v", err)
	}
	defer database.Close()

	app := &handlers.App{
		DB: database,
	}

	corsMiddleware := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000", "http://frontend:3000"},
		AllowedMethods:   []string{"GET", "POST", "PATCH", "OPTIONS"},
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
	http.Handle("PATCH /handle_live", middleware.AuthMiddleware(database, http.HandlerFunc(app.UpdateLivelocation)))
	http.Handle("PATCH /handle_profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.UpdateProfile)))
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

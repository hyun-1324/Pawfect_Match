package main

import (
	"fmt"
	"log"
	"matchMe/pkg/db"
	"matchMe/pkg/middleware"
	"net/http"
	"path/filepath"

	"matchMe/pkg/handlers"
)

func main() {
	const (
		dbname   = "matchMe"
		user     = "donghyun"
		password = ""
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

	buildPath := filepath.Join("..", "..", "..", "frontend", "build")
	fs := http.FileServer(http.Dir(buildPath))
	http.Handle("/", fs)

	http.Handle("GET /users/{id}", middleware.AuthMiddleware(database, http.HandlerFunc(app.User)))
	http.Handle("GET /users/{id}/profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.UserProfile)))
	http.Handle("GET /users/{id}/bio", middleware.AuthMiddleware(database, http.HandlerFunc(app.UserBio)))
	http.Handle("GET /me", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetMe)))
	http.Handle("GET /me/profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetMeProfile)))
	http.Handle("GET /me/bio", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetMeBio)))
	http.Handle("GET /recommendations", middleware.AuthMiddleware(database, http.HandlerFunc(app.Recommendations)))
	http.Handle("GET /connections", middleware.AuthMiddleware(database, http.HandlerFunc(app.Connections)))

	http.Handle("/register", middleware.RedirectIfAuthenticatedMiddleware(database, http.HandlerFunc(app.Register)))
	http.Handle("/login", middleware.RedirectIfAuthenticatedMiddleware(database, http.HandlerFunc(app.Login)))

	log.Println("Staring server on port 8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

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

	http.Handle("/users/{id}", middleware.AuthMiddleware(http.HandlerFunc(app.User)))
	http.Handle("/users/{id}/profile", middleware.AuthMiddleware(http.HandlerFunc(app.UserProfile)))
	http.Handle("/users/{id}/bio", middleware.AuthMiddleware(http.HandlerFunc(app.UserBio)))
	http.Handle("/me", middleware.AuthMiddleware(http.HandlerFunc(app.GetMe)))
	http.Handle("/me/profile", middleware.AuthMiddleware(http.HandlerFunc(app.GetMeProfile)))
	http.Handle("/me/bio", middleware.AuthMiddleware(http.HandlerFunc(app.GetMeBio)))
	http.Handle("/recommendations", middleware.AuthMiddleware(http.HandlerFunc(app.Recommendations)))
	http.Handle("/connections", middleware.AuthMiddleware(http.HandlerFunc(app.Connections)))

	log.Println("Staring server on port 8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

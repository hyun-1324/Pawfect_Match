package main

import (
	"fmt"
	"log"
	"matchMe/pkg/db"
	"net/http"
	"path/filepath"

	"matchMe/pkg/api"
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

	userAPI := &api.UserAPI{
		DB: database,
	}

	buildPath := filepath.Join("..", "..", "..", "frontend", "build")
	fs := http.FileServer(http.Dir(buildPath))
	http.Handle("/", fs)

	http.Handle("/users/{id}", userAPI.UserInfo)
	http.Handle("/users/{id}/profile", userAPI.UserProfile)
	http.Handle("/users/{id}/bio", userAPI.UserBio)
	http.Handle("/me", userAPI.UserBio)
	http.Handle("/me/profile", userAPI.UserBio)
	http.Handle("/me/bio", userAPI.UserBio)
	http.Handle("/recommendations", userAPI.RecommendationList)
	http.Handle("/connections", userAPI.ConnectionList)

	log.Println("Staring server on port 8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

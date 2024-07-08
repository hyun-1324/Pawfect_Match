package main

import (
	"fmt"
	"log"
	"matchMe/pkg/db"
	"net/http"
	"path/filepath"

	"matchMe/pkg/handlers"
)

func main() {
	const (
		host     = "localhost"
		port     = 5432
		user     = "donghyun"
		password = ""
		dbname   = "matchMe"
	)

	psqlInfo := fmt.Sprintf("dbname=%s user=%s password=%s host=%s port=%d sslmode=disable", dbname, user, password, host, port)
	database, err := db.InitDb(psqlInfo)
	if err != nil {
		log.Fatalf("Error initializing database: %v", err)
	}
	defer database.Close()

	dbHandler := &handlers.App{
		DB: database,
	}

	buildPath := filepath.Join("..", "frontend", "build")
	fs := http.FileServer(http.Dir(buildPath))
	http.Handle("/", fs)

	http.HandleFunc("/api/recommendations", dbHandler.Recommendation)

	log.Println("Staring server on port 8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

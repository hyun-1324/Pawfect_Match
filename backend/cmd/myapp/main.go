package main

import (
	"context"
	"fmt"
	"log"
	"matchMe/api/handlers"
	"matchMe/graph"
	"matchMe/graph/generated"
	"matchMe/internal/database"
	"matchMe/internal/middleware"
	"net/http"
	"os"

	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/playground"
	"github.com/rs/cors"
)

func main() {
	const (
		host     = "localhost" // docker-compose service name -> "postgres"
		port     = 5432
		dbname   = "postgres"
		user     = "postgres"
		password = "matchMe"
	)

	// Connect to the database
	psqlInfo := fmt.Sprintf("postgres://%v:%v@%v:%v/%v?sslmode=disable", user, password, host, port, dbname)
	database, err := database.InitDb(psqlInfo)
	if err != nil {
		log.Fatalf("Error initializing database: %v", err)
	}
	defer database.Close()

	app := &handlers.App{
		DB: database,
	}

	// Create a new CORS middleware
	corsMiddleware := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000", "http://frontend:3000"},
		AllowedMethods:   []string{"GET", "POST", "PATCH", "OPTIONS"},
		AllowedHeaders:   []string{"Origin", "X-Requested-With", "Content-Type", "Accept", "Authorization"},
		AllowCredentials: true,
	})

	// Create GraphQL resolver with database connection
	resolver := &graph.Resolver{
		DB: database,
	}

	// Create GraphQL server
	srv := handler.NewDefaultServer(generated.NewExecutableSchema(generated.Config{Resolvers: resolver}))

	// GraphQL authentication middleware
	graphqlHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Get user ID from the request
		userId := middleware.GetUserIdFromRequest(database, r)

		// Add user ID to context
		if userId != "" {
			ctx := context.WithValue(r.Context(), "userID", userId)
			r = r.WithContext(ctx)
		}

		// Serve GraphQL request
		srv.ServeHTTP(w, r)
	})

	// Check if we're in developer mode
	isDev := len(os.Args) > 1 && os.Args[1] == "-d"

	// Setup GraphQL endpoints
	http.Handle("/graphql", middleware.AuthMiddleware(database, graphqlHandler))

	// Only enable playground in developer mode
	if isDev {
		http.Handle("/playground", playground.Handler("GraphQL Playground", "/graphql"))
		log.Println("GraphQL playground available at /playground")
	}

	// Handle the REST API routes
	http.Handle("/ws", middleware.AuthMiddleware(database, http.HandlerFunc(app.HandleConnections)))

	http.Handle("GET /users/{id}", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetUser)))
	http.Handle("GET /users/{id}/profile", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetUserProfile)))
	http.Handle("GET /users/{id}/bio", middleware.AuthMiddleware(database, http.HandlerFunc(app.GetUserBio)))
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

	log.Println("Starting server on port 8080...")
	if err := http.ListenAndServe(":8080", handler); err != nil {
		log.Fatal(err)
	}
}

package database

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"
)

// initializes the database connection
func InitDb(dataSourceName string) (*sql.DB, error) {
	db, err := sql.Open("postgres", dataSourceName)
	if err != nil {
		log.Fatalf("failed to connect to the database: %v", err)
	}

	if err = db.Ping(); err != nil {
		log.Fatalf("failed to ping the database: %v", err)
	}

	fmt.Println("Database connection established")

	// if shouldRunMigration(db) {
	// 	runMigration(db)
	// }

	return db, nil

}

// func shouldRunMigration(db *sql.DB) bool {
// 	var count int
// 	query := "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users'"
// 	err := db.QueryRow(query).Scan(&count)
// 	if err != nil {
// 		log.Fatalf("failed to check if migration is needed: %v", err)
// 	}

// 	return count == 0
// }

// func runMigration(db *sql.DB) {
// 	migrationFile := filepath.Join("..", "..", "internal", "database", "initial.sql")
// 	migrationSQL, err := os.ReadFile(migrationFile)
// 	if err != nil {
// 		log.Fatalf("failed to read migration file: %v", err)
// 	}

// 	_, err = db.Exec(string(migrationSQL))
// 	if err != nil {
// 		log.Fatalf("failed to execute migration: %v", err)
// 	}

// 	fmt.Println("Database migration completed")
// }

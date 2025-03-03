package graph

import (
	"context"
	"database/sql"
	"errors"
)

// This file will not be regenerated automatically.
//
// It serves as dependency injection for your app, add any dependencies you require here.

// Resolver holds references to your database
type Resolver struct {
	DB *sql.DB
}

// GetUserIDFromContext extracts the authenticated user ID from the context
func GetUserIDFromContext(ctx context.Context) (string, error) {
	userID, ok := ctx.Value("userID").(string)
	if !ok || userID == "" {
		return "", ErrUnauthenticated
	}
	return userID, nil
}

// ErrUnauthenticated represents an authentication error
var ErrUnauthenticated = errors.New("user not authenticated")

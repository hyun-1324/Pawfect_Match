package middleware

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"matchMe/pkg/util"
	"net/http"
	"os"
	"strings"
	"time"
)

type contextKey string

const UserIDKey contextKey = "userID"
const secretKeyEnv = "JWT_SECRET"

type JWTHeader struct {
	Alg string `json:"alg"`
	Typ string `json:"typ"`
}

type JWTPayload struct {
	Sub string `json:"sub"`
	Exp int64  `json:"exp"`
}

func base64Encode(data []byte) string {
	return strings.TrimRight(base64.URLEncoding.EncodeToString(data), "=")
}

func base64Decode(s string) ([]byte, error) {
	return base64.URLEncoding.DecodeString(strings.TrimRight(s, "="))
}

func GenerateJWT(userID string) (string, error) {
	header := JWTHeader{
		Alg: "HS256",
		Typ: "JWT",
	}

	payload := JWTPayload{
		Sub: userID,
		Exp: time.Now().Add(time.Hour * 24).Unix(),
	}

	// Encode the header and payload in JSON
	headerJson, err := json.Marshal(header)
	if err != nil {
		return "", err
	}

	payloadJson, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	// Encode the header and payload in base64
	encodedHeader := base64Encode(headerJson)
	encodedPayload := base64Encode(payloadJson)

	// Generate the signature
	signature := generateSignature(encodedHeader, encodedPayload)

	// Combine the encoded header, payload, and signature
	jwt := fmt.Sprintf("%s.%s.%s", encodedHeader, encodedPayload, signature)
	return jwt, nil
}

func generateSignature(header, payload string) string {
	secretKey := []byte(getSecretKey())
	mac := hmac.New(sha256.New, secretKey)
	mac.Write([]byte(header + "." + payload))
	return base64Encode(mac.Sum(nil))
}

func getSecretKey() string {
	secretKey := os.Getenv(secretKeyEnv)
	if secretKey == "" {
		log.Fatal("JWT_SECRET environment variable not set")
	}
	return secretKey
}

func ValidateJWT(db *sql.DB, token string) (string, int64, error) {
	var exists bool
	err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM jwt_blacklist WHERE token = $1)", token).Scan(&exists)
	if err != nil {
		return "", 0, fmt.Errorf("failed to read data: %v", err)
	}
	if exists {
		return "", 0, fmt.Errorf("token is blacklisted")
	}

	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return "", 0, fmt.Errorf("invalid token")
	}

	header, err := base64Decode(parts[0])
	if err != nil {
		return "", 0, err
	}

	var jwtHeader JWTHeader
	if err := json.Unmarshal(header, &jwtHeader); err != nil {
		return "", 0, err
	}

	if jwtHeader.Alg != "HS256" {
		return "", 0, fmt.Errorf("invalid algorithm")
	}

	payload, err := base64Decode(parts[1])
	if err != nil {
		return "", 0, err
	}

	var jwtPayload JWTPayload
	if err := json.Unmarshal(payload, &jwtPayload); err != nil {
		return "", 0, err
	}

	if time.Now().Unix() > jwtPayload.Exp {
		return "", 0, fmt.Errorf("token expired")
	}

	signature := parts[2]
	expectedSignature := generateSignature(parts[0], parts[1])
	if !hmac.Equal([]byte(signature), []byte(expectedSignature)) {
		return "", 0, fmt.Errorf("invalid signature")
	}

	return jwtPayload.Sub, jwtPayload.Exp, nil
}

func AuthMiddleware(db *sql.DB, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("jwt_token")
		if err != nil {
			if err != http.ErrNoCookie {
				util.HandleError(w, "unauthorized access", http.StatusInternalServerError, err)
				return
			}
			util.HandleError(w, "failed to authenticate the user", http.StatusInternalServerError, err)
		}

		token := cookie.Value

		userId, _, err := ValidateJWT(db, token)
		if err != nil {
			util.HandleError(w, "unauthorized access", http.StatusInternalServerError, err)
			return
		}

		ctx := context.WithValue(r.Context(), UserIDKey, userId)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func AddTokenToBlacklist(db *sql.DB, token string) error {
	_, expirationTime, err := ValidateJWT(db, token)
	if err != nil {
		return err
	}

	expTime := time.Unix(expirationTime, 0)

	_, err = db.Exec(`INSERT INTO jwt_blacklist (token, expires_at) VALUES ($1, $2)`,
		token, expTime)
	if err != nil {
		return err
	}

	return nil
}

func GetUserId(r *http.Request) string {
	if userId, ok := r.Context().Value(UserIDKey).(string); ok {
		return userId
	}
	return ""
}

func RedirectIfAuthenticated(db *sql.DB, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID := GetUserId(r)
		if userID != "" {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		next.ServeHTTP(w, r)
	})
}

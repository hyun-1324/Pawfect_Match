package handlers

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"matchMe/pkg/models"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) Register(w http.ResponseWriter, r *http.Request) {
	var req models.Register
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	if req.Password == "" || len([]byte(req.Password)) > 60 {
		http.Error(w, "invalid password", http.StatusBadRequest)
		return
	}

	if req.ConfirmPassword != req.Password {
		http.Error(w, "passwords do not match", http.StatusBadRequest)
		return
	}

	err := validateEmailData(req.Email)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = validateUserStringData(req.DogName, 30)
	if err != nil {
		http.Error(w, "invalid dog name", http.StatusBadRequest)
		return
	}

	if !(req.Gender == "female" || req.Gender == "male") {
		http.Error(w, "invalid dog gender", http.StatusBadRequest)
		return
	}

	if !(req.Size >= 0 && req.Size <= 100) {
		http.Error(w, "invalid dog size", http.StatusBadRequest)
		return
	}

	if !(req.EnergyLevel == "low" || req.EnergyLevel == "medium" || req.EnergyLevel == "high") {
		http.Error(w, "invalid dog energy level", http.StatusBadRequest)
		return
	}

	if !(req.FavoritePlayStyle == "wrestling" || req.FavoritePlayStyle == "lonely wolf" || req.FavoritePlayStyle == "cheerleading" || req.FavoritePlayStyle == "chasing" || req.FavoritePlayStyle == "tugging" || req.FavoritePlayStyle == "ripping" || req.FavoritePlayStyle == "soft touch" || req.FavoritePlayStyle == "body slamming") {
		http.Error(w, "invalid dog favorite play style", http.StatusBadRequest)
		return
	}

	if req.Age < 0 || req.Age > 30 {
		http.Error(w, "invalid dog age", http.StatusBadRequest)
		return
	}

	if req.PreferredDistance < 0 || req.PreferredDistance > 100 {
		http.Error(w, "Invalid preferred distance", http.StatusBadRequest)
		return
	}

	if !(req.PreferredGender == "male" || req.PreferredGender == "female" || req.PreferredGender == "any") {
		http.Error(w, "invalid preferred gender", http.StatusBadRequest)
		return
	}

	if len([]byte(req.AboutMe)) > 255 {
		http.Error(w, "invalid about me", http.StatusBadRequest)
		return
	}

	var exists int
	err = app.DB.QueryRow(`SELECT 1 FROM users WHERE email = $1`, req.Email).Scan(&exists)
	if err != nil && err != sql.ErrNoRows {
		http.Error(w, "failed to register user", http.StatusInternalServerError)
		return
	}
	if exists == 1 {
		http.Error(w, "email already taken", http.StatusBadRequest)
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "failed to generate hashed password", http.StatusInternalServerError)
		return
	}

	var userId int
	err = app.DB.QueryRow(`INSERT INTO users (email, password, about_me, dog_name) 
	VALUES ($1, $2, $3, $4) RETURNING id`,
		req.Email, hashedPassword, req.AboutMe, req.DogName).Scan(&userId)
	if err != nil {
		http.Error(w, "failed to insert user data", http.StatusInternalServerError)
		return
	}

	_, err = app.DB.Exec(`INSERT INTO biographical_data (user_id, dog_gender,
	 dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age,
	 preferred_distance, preferred_gender, preferred_neutered) VALUES ($1, $2, $3,
	  $4, $5, $6, $7, $8, $9, $10)`, userId, req.Gender, req.Neutered, req.Size,
		req.EnergyLevel, req.FavoritePlayStyle, req.Age, req.PreferredDistance,
		req.PreferredGender, req.PreferredNeutered)
	if err != nil {
		http.Error(w, "failed to insert bio data", http.StatusInternalServerError)
		return
	}

	err = processProfilePictureData(r, app, userId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	calculateRecommendationScore(app, userId)

	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

func validateEmailData(email string) error {
	emailRegex := `^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`
	isValid := regexp.MustCompile(emailRegex).MatchString(email)
	if !isValid || email == "" || len([]byte(email)) > 50 {
		return fmt.Errorf("invalid email address")
	}
	return nil
}

func validateUserStringData(value string, maxlength int) error {
	if len([]byte(value)) > maxlength {
		return fmt.Errorf("invalid value")
	}
	if trimmedValue := strings.TrimSpace(value); trimmedValue == "" {
		return fmt.Errorf("invalid value")
	}
	return nil
}

func processProfilePictureData(r *http.Request, app *App, userId int) error {
	profilePicture, fileHeader, err := r.FormFile("profilePicture")
	if err != nil {
		if err == http.ErrMissingFile {
			return nil
		}
	}

	defer profilePicture.Close()

	// Check if file is valid
	mimeType := fileHeader.Header.Get("Content-Type")
	if !models.AllowedMimeType[mimeType] {
		err := fmt.Errorf("invalid file type")
		return err
	}

	if fileHeader.Size > 2000000 {
		err := fmt.Errorf("file is too large")
		return err
	}

	// Generate new filename for safety reasons
	buf := make([]byte, 16)
	if _, err = rand.Read(buf); err != nil {
		return err
	}
	newFileName := hex.EncodeToString(buf) + filepath.Ext(fileHeader.Filename)

	// Save file to local filesystem
	uploadDir := filepath.Join("..", "..", "uploads")
	filePath := filepath.Join(uploadDir, newFileName)
	outFile, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer outFile.Close()

	_, err = profilePicture.Seek(0, 0)
	if err != nil {
		return err
	}

	_, err = outFile.ReadFrom(profilePicture)
	if err != nil {
		return err
	}

	// Insert file into database
	fileBytes := make([]byte, fileHeader.Size)
	if _, err = profilePicture.Read(fileBytes); err != nil {
		return err
	}

	fileURL := "localhost:8080/uploads/" + newFileName

	query := `INSERT INTO profile_pictures(user_id, file_name, file_data, file_type, file_url) VALUES ($1, $2, $3, $4, $5)`
	_, err = app.DB.Exec(query, userId, newFileName, fileBytes, mimeType, fileURL)
	if err != nil {
		return err
	}

	return nil
}

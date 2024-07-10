package handlers

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"matchMe/pkg/models"
	"net/http"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) Register(w http.ResponseWriter, r *http.Request) {
	var req models.Register
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if req.Password == "" || len([]byte(req.Password)) > 50 {
		http.Error(w, "Invalid password", http.StatusBadRequest)
		return
	}
	if req.ConfirmPassword != req.Password {
		http.Error(w, "Passwords do not match", http.StatusBadRequest)
		return
	}
	err := validateEmailData(req.Email)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = validateUserStringData(req.DogName, 30)
	if err != nil {
		http.Error(w, "Invalid dog name", http.StatusBadRequest)
		return
	}

	if !(req.Gender == "female" || req.Gender == "male") {
		http.Error(w, "Invalid dog gender", http.StatusBadRequest)
		return
	}

	if !(req.Size >= 0 && req.Size <= 100) {
		http.Error(w, "Invalid dog size", http.StatusBadRequest)
		return
	}

	if !(req.EnergyLevel == "low" || req.EnergyLevel == "medium" || req.EnergyLevel == "high") {
		http.Error(w, "Invalid dog energy level", http.StatusBadRequest)
		return
	}

	if !(req.FavoritePlayStyle == "wrestling" || req.FavoritePlayStyle == "lonely wolf" || req.FavoritePlayStyle == "cheerleading" || req.FavoritePlayStyle == "chasing" || req.FavoritePlayStyle == "tugging" || req.FavoritePlayStyle == "ripping" || req.FavoritePlayStyle == "soft touch" || req.FavoritePlayStyle == "body slamming") {
		http.Error(w, "Invalid dog favorite play style", http.StatusBadRequest)
		return
	}

	if req.Age < 0 || req.Age > 30 {
		http.Error(w, "Invalid dog age", http.StatusBadRequest)
		return
	}

	if req.PreferredDistance < 0 || req.PreferredDistance > 100 {
		http.Error(w, "Invalid preferred distance", http.StatusBadRequest)
		return
	}

	if !(req.PreferredGender == "male" || req.PreferredGender == "female" || req.PreferredGender == "any") {
		http.Error(w, "Invalid preferred gender", http.StatusBadRequest)
		return
	}

	err = validateUserStringData(req.AboutMe, 255)
	if err != nil {
		http.Error(w, "Invalid about me", http.StatusBadRequest)
		return
	}

	var exists int
	err = app.DB.QueryRow(`SELECT 1 FROM users WHERE email = $1`, req.Email).Scan(&exists)
	if err != nil && err != sql.ErrNoRows {
		http.Error(w, "Failed to register user", http.StatusInternalServerError)
		return
	}
	if exists == 1 {
		http.Error(w, "Email already taken", http.StatusBadRequest)
		return
	}

	profilePictureId, err := processProfilePictureData(r, app)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "Failed to generate hashed password", http.StatusInternalServerError)
		return
	}

	_, err = app.DB.Exec(`INSERT INTO users (email, password, dog_name, dog_gender, dog_netured, dog_size, dog_energy_level, dog_favorite_play_style, 
	dog_age, preferred_distance, preferred_gender, preferred_netured, about_me, profile_picture_id) 
	VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
		req.Email, hashedPassword, req.DogName, req.Gender, req.Neutered, req.Size, req.EnergyLevel, req.FavoritePlayStyle,
		req.Age, req.PreferredDistance, req.PreferredGender, req.PreferredNeutered, req.AboutMe, profilePictureId)
	if err != nil {
		http.Error(w, "Failed to register user", http.StatusInternalServerError)
		return
	}

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
	if trmimmedValue := strings.TrimSpace(value); trmimmedValue == "" {
		return fmt.Errorf("invalid value")
	}
	return nil
}

func processProfilePictureData(r *http.Request, app *App) (int64, error) {
	profilePicture, fileHeader, err := r.FormFile("profilePicture")
	if err != nil {
		if err == http.ErrMissingFile {
			profilePicture = nil
			fileHeader = nil
		}
	}

	if profilePicture != nil {
		// Check if file is valid
		mimeType := fileHeader.Header.Get("Content-Type")
		if !models.AllowedMimeType[mimeType] {
			err := fmt.Errorf("invalid file type")
			return 0, err
		}

		if fileHeader.Size > 2000000 {
			err := fmt.Errorf("file is too large")
			return 0, err
		}

		// Generate new filename for safety reasons
		buf := make([]byte, 16)
		_, err := rand.Read(buf)
		if err != nil {
			return 0, err
		}
		newFileName := hex.EncodeToString(buf) + filepath.Ext(fileHeader.Filename)

		// Insert file into database
		fileBytes := make([]byte, fileHeader.Size)
		_, err = profilePicture.Read(fileBytes)
		if err != nil {
			return 0, err
		}

		var pictureId int64
		query := `INSERT INTO profile_pictures(file_name, file_data, file_type) VALUES ($1, $2, $3) RETURNING id`
		err = app.DB.QueryRow(query, newFileName, fileBytes, mimeType).Scan(&pictureId)
		if err != nil {
			return 0, err
		}

		return pictureId, nil
	} else {
		return 0, nil
	}
}

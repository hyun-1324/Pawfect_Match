package handlers

import (
	"crypto/rand"
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

	err = checkUserDataValidation(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	latitude, longitude, err := checkLocationData(req.LocationOptions)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var exists bool
	err = app.DB.QueryRow(`SELECT EXISTS (SELECT 1 FROM users WHERE email = $1)`, req.Email).Scan(&exists)
	if err != nil {
		http.Error(w, "failed to register user", http.StatusInternalServerError)
		return
	}
	if exists {
		http.Error(w, "email already taken", http.StatusBadRequest)
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "failed to generate hashed password", http.StatusInternalServerError)
		return
	}

	err = app.DB.QueryRow(`INSERT INTO users (email, password, about_me, dog_name) 
	VALUES ($1, $2, $3, $4) RETURNING id`,
		req.Email, hashedPassword, req.AboutMe, req.DogName).Scan(&req.Id)
	if err != nil {
		http.Error(w, "failed to insert user data", http.StatusInternalServerError)
		return
	}

	_, err = app.DB.Exec(`INSERT INTO biographical_data (user_id, dog_gender,
	 dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age,
	 preferred_distance, preferred_gender, preferred_neutered) VALUES ($1, $2, $3,
	  $4, $5, $6, $7, $8, $9, $10)`, req.Id, req.Gender, req.Neutered, req.Size,
		req.EnergyLevel, req.FavoritePlayStyle, req.Age, req.PreferredDistance,
		req.PreferredGender, req.PreferredNeutered)
	if err != nil {
		http.Error(w, "failed to insert bio data", http.StatusInternalServerError)
		return
	}

	if latitude != 0 && longitude != 0 {
		_, err = app.DB.Exec(`INSERT INTO locations (user_id, option, latitude, longitude) VALUES ($1, $2, $3, $4)`, req.Id, req.LocationOptions, latitude, longitude)
		if err != nil {
			http.Error(w, "failed to insert location", http.StatusInternalServerError)
			return
		}
	}

	err = processProfilePictureData(r, app, req.Id, true)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	calculateRecommendationScore(app, req.Id)

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

func checkUserDataValidation(req models.Register) error {

	err := validateUserStringData(req.DogName, 30)
	if err != nil {
		return fmt.Errorf("invalid dog name")

	}

	if !(req.Gender == "female" || req.Gender == "male") {
		return fmt.Errorf("invalid dog gender")
	}

	if !(req.Size >= 0 && req.Size <= 100) {
		return fmt.Errorf("invalid dog size")
	}

	if !(req.EnergyLevel == "low" || req.EnergyLevel == "medium" || req.EnergyLevel == "high") {
		return fmt.Errorf("invalid dog energy level")
	}

	if !(req.FavoritePlayStyle == "wrestling" || req.FavoritePlayStyle == "lonely wolf" || req.FavoritePlayStyle == "cheerleading" || req.FavoritePlayStyle == "chasing" || req.FavoritePlayStyle == "tugging" || req.FavoritePlayStyle == "ripping" || req.FavoritePlayStyle == "soft touch" || req.FavoritePlayStyle == "body slamming") {
		return fmt.Errorf("invalid dog favorite play style")
	}

	if req.Age < 0 || req.Age > 30 {
		return fmt.Errorf("invalid dog age")
	}

	if req.PreferredDistance < 0 || req.PreferredDistance > 30 {
		return fmt.Errorf("invalid preferred distance")
	}

	if !(req.PreferredGender == "male" || req.PreferredGender == "female" || req.PreferredGender == "any") {
		return fmt.Errorf("invalid preferred gender")
	}

	if len([]byte(req.AboutMe)) > 255 {
		return fmt.Errorf("invalid about me")
	}

	return nil
}

func checkLocationData(location string) (float64, float64, error) {
	var latitude, longitude float64
	switch {
	case location == "live":
		latitude, longitude = 0, 0
	case location == "Helsinki":
		latitude, longitude = 60.1695, 24.9354
	case location == "Tampere":
		latitude, longitude = 61.4978, 23.7610
	case location == "Turku":
		latitude, longitude = 60.4518, 22.2666
	case location == "Jyväskylä":
		latitude, longitude = 62.2416, 25.7594
	case location == "Kuopio":
		latitude, longitude = 62.8988, 27.6784
	default:
		return 0, 0, fmt.Errorf("invalid location")
	}

	return latitude, longitude, nil

}

func processProfilePictureData(r *http.Request, app *App, userId int, addFile bool) error {
	profilePicture, fileHeader, err := r.FormFile("profilePicture")
	if err != nil {
		if err == http.ErrMissingFile || addFile == false {
			query := `DELETE FROM profile_pictures WHERE user_id = $1`
			_, err = app.DB.Exec(query, userId)
			if err != nil {
				return err
			}
			return nil
		} else {
			return err
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

	// Insert file into database
	fileBytes := make([]byte, fileHeader.Size)
	if _, err = profilePicture.Read(fileBytes); err != nil {
		return err
	}

	fileURL := "localhost:3000/images/" + newFileName

	query := `INSERT INTO profile_pictures (user_id, file_name, file_data, file_type, file_url)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (user_id)
DO UPDATE SET
    file_name = EXCLUDED.file_name,
    file_data = EXCLUDED.file_data,
    file_type = EXCLUDED.file_type,
    file_url = EXCLUDED.file_url`
	_, err = app.DB.Exec(query, userId, newFileName, fileBytes, mimeType, fileURL)
	if err != nil {
		return err
	}

	return nil
}

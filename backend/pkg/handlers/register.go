package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"matchMe/pkg/models"
	"matchMe/pkg/utils"
	"net/http"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

func (app *App) Register(w http.ResponseWriter, r *http.Request) {
	var req models.Register

	jsonData := r.FormValue("json")
	if jsonData == "" {
		utils.HandleError(w, "invalid request", http.StatusBadRequest, fmt.Errorf("missing json data"))
		return
	}

	if err := json.Unmarshal([]byte(jsonData), &req); err != nil {
		utils.HandleError(w, "failed to decode JSON", http.StatusInternalServerError, fmt.Errorf("failed to decode JSON data for registration: %v", err))
		return
	}

	if req.Password == "" || len([]byte(req.Password)) > 60 {
		utils.HandleError(w, "invalid password", http.StatusBadRequest, nil)
		return
	}

	if req.ConfirmPassword != req.Password {
		utils.HandleError(w, "passwords do not match", http.StatusBadRequest, nil)
		return
	}

	err := validateEmailData(req.Email)
	if err != nil {
		utils.HandleError(w, "invalid email", http.StatusBadRequest, fmt.Errorf("failed to validate email for registration: %v", err))
		return
	}

	err = checkUserDataValidation(req)
	if err != nil {
		utils.HandleError(w, err.Error(), http.StatusBadRequest, fmt.Errorf("failed to validate user data for registration: %v", err))
		return
	}

	latitude, longitude, err := checkLocationData(req.PreferredLocation)
	if err != nil {
		utils.HandleError(w, "invalid location", http.StatusBadRequest, fmt.Errorf("failed to validate location data for registration: %v", err))
		return
	}

	var exists bool
	err = app.DB.QueryRow(`SELECT EXISTS (SELECT 1 FROM users WHERE email = $1)`, req.Email).Scan(&exists)
	if err != nil {
		utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to check if user exists for registration: %v", err))
		return
	}
	if exists {
		utils.HandleError(w, "email already taken", http.StatusInternalServerError, nil)
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to hash password: %v", err))
		return
	}

	err = app.DB.QueryRow(`INSERT INTO users (email, password, about_me, dog_name) 
	VALUES ($1, $2, $3, $4) RETURNING id`,
		req.Email, hashedPassword, req.AboutMe, req.DogName).Scan(&req.Id)
	if err != nil {
		utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to insert user data: %v", err))
		return
	}
	_, err = app.DB.Exec(`INSERT INTO biographical_data (user_id, dog_gender,
	 dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age,
	 preferred_distance, preferred_gender, preferred_neutered, preferred_location) VALUES ($1, $2, $3,
	  $4, $5, $6, $7, $8, $9, $10, $11)`, req.Id, req.Gender, req.Neutered, req.Size,
		req.EnergyLevel, req.FavoritePlayStyle, req.Age, req.PreferredDistance,
		req.PreferredGender, req.PreferredNeutered, req.PreferredLocation)
	if err != nil {
		utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to insert bio data: %v", err))
		return
	}

	if latitude != 0 && longitude != 0 {
		_, err = app.DB.Exec(`INSERT INTO locations (user_id, option, latitude, longitude) VALUES ($1, $2, $3, $4)`, req.Id, req.PreferredLocation, latitude, longitude)
		if err != nil {
			utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to insert location data: %v", err))
			return
		}
	}

	err = processProfilePictureData(r, app, req.Id, req.AddPicture)
	if err != nil {
		utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to process profile picture data: %v", err))
		return
	}

	err = utils.CalculateRecommendationScore(app.DB, req.Id)
	if err != nil {
		utils.HandleError(w, "failed to register user", http.StatusInternalServerError, fmt.Errorf("failed to calculate recommendation score: %v", err))
		return
	}

	err = json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	if err != nil {
		utils.HandleError(w, "failed to register", http.StatusInternalServerError, fmt.Errorf("failed to encode response for registration: %v", err))
		return
	}
}

func validateEmailData(email string) error {
	emailRegex := `^[^\s@]+@[^\s@]+\.[^\s@]{2,}$`
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

	floatSize, err := strconv.ParseFloat(req.Size, 64)
	if err != nil {
		return fmt.Errorf("failed to parse dog size")
	}

	if !(floatSize > 0 && floatSize <= 30) {
		return fmt.Errorf("invalid dog size")
	}

	if !(req.EnergyLevel == "low" || req.EnergyLevel == "medium" || req.EnergyLevel == "high") {
		return fmt.Errorf("invalid dog energy level")
	}

	if !(req.FavoritePlayStyle == "wrestling" || req.FavoritePlayStyle == "lonely wolf" || req.FavoritePlayStyle == "cheerleading" || req.FavoritePlayStyle == "chasing" || req.FavoritePlayStyle == "tugging" || req.FavoritePlayStyle == "ripping" || req.FavoritePlayStyle == "soft touch" || req.FavoritePlayStyle == "body slamming") {
		return fmt.Errorf("invalid dog favorite play style")
	}

	intAge, err := strconv.Atoi(req.Age)
	if err != nil {
		return fmt.Errorf("failed to parse dog age")
	}

	if intAge < 0 || intAge > 30 {
		return fmt.Errorf("invalid dog age")
	}

	intPreferredDistance, err := strconv.Atoi(req.PreferredDistance)
	if err != nil {
		return fmt.Errorf("failed to parse preferred distance")
	}

	if intPreferredDistance <= 0 || intPreferredDistance > 30 {
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
	case location == "Live":
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
		if err == http.ErrMissingFile && !addFile {
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

	fileURL := "/profile_pictures/" + newFileName

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

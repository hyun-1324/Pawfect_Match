package handlers

import (
	"matchMe/pkg/models"
	"matchMe/pkg/util"
	"strconv"
)

func calculateRecommendationScore(app *App, userId int) error {
	userBioData, err := getUserBioData(app)
	if err != nil {
		return err
	}

	executeRecommendationAlgorithm(app, userId, userBioData)

	return nil

}

func getUserBioData(app *App) (map[int]models.UserBioResponse, error) {
	rows, err := app.DB.Query("SELECT user_id, dog_gender, dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, preferred_gender, preferred_neutered FROM biographical_data")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	userBioData := make(map[int]models.UserBioResponse)

	for rows.Next() {
		var data models.UserBioResponse
		err := rows.Scan(&data.Id, &data.Gender, &data.Neutered, &data.Size, &data.EnergyLevel, &data.FavoritePlayStyle, &data.Age, &data.PreferredDistance, &data.PreferredGender, &data.PreferredNeutered)
		if err != nil {
			return nil, err
		}

		numId, err := strconv.Atoi(data.Id)
		if err != nil {
			return nil, err
		}

		userBioData[numId] = data
	}

	return userBioData, nil

}

func executeRecommendationAlgorithm(app *App, userId int, userBioData map[int]models.UserBioResponse) error {

	userBio := userBioData[userId]

	for dataId, data := range userBioData {
		if dataId == userId {
			continue
		}
		smallId, largeId := util.OrderPair(userId, dataId)

		if (userBio.PreferredNeutered && !data.Neutered) || (!userBio.Neutered && data.PreferredNeutered) {
			_, err := app.DB.Exec("INSERT INTO matches (compatible_neutered, user_id1, user_id2) VALUES ($1, $2, $3)", false, smallId, largeId)
			if err != nil {
				return err
			}
			continue
		} else {
			_, err := app.DB.Exec("INSERT INTO matches (compatible_neutered, user_id1, user_id2) VALUES ($1, $2, $3)", true, smallId, largeId)
			if err != nil {
				return err
			}
		}

		if ((userBio.PreferredGender != "any" && data.PreferredGender != "any") && (userBio.Gender != data.PreferredGender) || (userBio.PreferredGender != data.Gender)) || ((userBio.PreferredGender != "any" && data.PreferredGender == "any") && (userBio.PreferredGender != data.Gender)) || ((userBio.PreferredGender == "any" && data.PreferredGender != "any") && (userBio.Gender != data.PreferredGender)) {
			_, err := app.DB.Exec("INSERT INTO matches (compatible_gender, user_id1, user_id2) VALUES ($1, $2, $3)", false, smallId, largeId)
			if err != nil {
				return err
			}
			continue
		} else {
			_, err := app.DB.Exec("INSERT INTO matches (compatible_gender, user_id1, user_id2) VALUES ($1, $2, $3)", true, smallId, largeId)
			if err != nil {
				return err
			}
		}

		compatiblePlayStyle := checkPlayStyleCompatibility(userBio.FavoritePlayStyle, data.FavoritePlayStyle)
		_, err := app.DB.Exec("INSERT INTO matches (compatible_play_style, user_id1, user_id2) VALUES ($1, $2, $3)", compatiblePlayStyle, smallId, largeId)
		if err != nil {
			return err
		}

		if !compatiblePlayStyle {
			continue
		}

		compatibleSize := checkSizeCompatibility(userBio.Size, data.Size)
		_, err = app.DB.Exec("INSERT INTO matches (compatible_size, user_id1, user_id2) VALUES ($1, $2, $3)", compatibleSize, smallId, largeId)
		if err != nil {
			return err
		}

		if !compatibleSize {
			continue
		}

		matchScore := calculateMatchScore(userBio, data)
		_, err = app.DB.Exec("UPDATE matches SET match_score = $1 WHERE user_id1 = $2 AND user_id2 = $3", matchScore, smallId, largeId)
		if err != nil {
			return err
		}

	}

	return nil
}

func checkPlayStyleCompatibility(style1, style2 string) bool {
	incompatibleStyles := map[string][]string{
		"wrestling":     {"lonely wolf", "soft touch"},
		"body slamming": {"lonely wolf", "soft touch"},
		"lonely wolf":   {"wrestling", "body slamming", "chasing", "togging", "nipping"},
		"soft touch":    {"wrestling", "body slamming"},
		"chasing":       {"lonely wolf"},
		"togging":       {"lonely wolf"},
		"nipping":       {"lonely wolf"},
	}

	for _, incompatible := range incompatibleStyles[style1] {
		if style2 == incompatible {
			return false
		}
	}
	return true
}

func checkSizeCompatibility(size1, size2 float32) bool {
	sizeThresholds := []float32{4, 8, 16, 25}

	// Determine the categories for each size
	category1 := determineSizeCategory(size1, sizeThresholds)
	category2 := determineSizeCategory(size2, sizeThresholds)

	// Check if the size difference is within one category
	return util.Abs(category1-category2) <= 1
}

func determineSizeCategory(size float32, thresholds []float32) int {
	for i, threshold := range thresholds {
		if size <= threshold {
			return i
		}
	}
	return len(thresholds)
}

func calculateMatchScore(userBio1, userBio2 models.UserBioResponse) float64 {
	score := 0.0

	energyScores := map[string]map[string]float64{
		"Low":    {"Low": 7, "Medium": 4, "High": 1},
		"Medium": {"Low": 4, "Medium": 7, "High": 4},
		"High":   {"Low": 1, "Medium": 4, "High": 7},
	}
	score += energyScores[userBio1.EnergyLevel][userBio2.EnergyLevel]

	size1 := userBio1.Size
	size2 := userBio2.Size
	sizeRatio := size1 / size2
	switch {
	case sizeRatio >= 0.9 && sizeRatio <= 1.2:
		score += 10
	case sizeRatio >= 0.8 && sizeRatio <= 1.3:
		score += 8
	case sizeRatio >= 0.7 && sizeRatio <= 1.4:
		score += 6
	case sizeRatio >= 0.6 && sizeRatio <= 1.6:
		score += 4
	case sizeRatio >= 0.5 && sizeRatio <= 1.7:
		score += 2
	case sizeRatio >= 0.4 && sizeRatio <= 2.0:
		score += 1
	}

	ageDiff := util.Abs(userBio1.Age - userBio2.Age)
	switch {
	case ageDiff <= 3:
		score += 1
	case ageDiff <= 4:
		score += 0.8
	case ageDiff <= 6:
		score += 0.6
	case ageDiff <= 8:
		score += 0.4
	case ageDiff <= 10:
		score += 0.2
	default:
		score += 0.1
	}

	return score
}

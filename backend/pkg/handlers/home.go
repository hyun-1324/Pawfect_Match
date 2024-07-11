package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"net/http"
)

func (app *App) Home(w http.ResponseWriter, r *http.Request) {
	var locationInfo models.LocationInfo
	if err := json.NewDecoder(r.Body).Decode(&locationInfo); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	userId := middleware.GetUserId(r)

	query := `INSERT INTO locations (user_id, latitude, longitude) VALUES ($1, $2, $3) ON CONFLICT (user_id) DO UPDATE SET latitude = $2, longitude = $3;`
	_, err := app.DB.Exec(query, userId, locationInfo.Latitude, locationInfo.Longitude)
	if err != nil {
		http.Error(w, "failed to insert location", http.StatusInternalServerError)
		return
	}

}

// 	query = `
// 	DO $$
// 	BEGIN
// 		WITH user_distance AS (
// 				SELECT
// 					m.id AS match_id
// 					m.user_id1,
// 					m.user_id2,
// 					ST_Distance(
// 					l1.geom::geography,
// 					l2.geom::geography
// 					) / 1000 AS distance,
// 					bd1.preferred_distance AS preferred_distance1_km,
// 					bd2.preferred_distance AS preferred_distance2_km
// 				FROM matches m
// 					JOIN locations l1 ON m.user_id1 = l1.user_id
// 					JOIN locations l2 ON m.user_id2 = l2.user_id
// 					JOIN biographical_data bd1 ON m.user_id1 = bd1.user_id
// 					JOIN biographical_data bd2 ON m.user_id2 = bd2.user_id
// 				WHERE m.user_id1 = $1 OR m.user_id2 = $1
// 	)
// 	UPDATE matches
// 	SET compatible_distance = TRUE
// 	FROM user_distances ud
// 	WHERE matches.id = ud.match_id
// 	AND ud.distance <= LEAST(ud.preferred_distance1_km, ud.preferred_distance2_km);
// 	END $$;
// `

// 	_, err = app.DB.Exec(query, userId)
// 	if err != nil {
// 		http.Error(w, "failed to update matches", http.StatusInternalServerError)
// 		return
// 	}

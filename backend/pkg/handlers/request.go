package handlers

import (
	"encoding/json"
	"matchMe/pkg/middleware"
	"matchMe/pkg/models"
	"matchMe/pkg/util"
	"net/http"
	"strconv"
)

func (app *App) SendConnectionRequest(w http.ResponseWriter, r *http.Request) {
	fromId := middleware.GetUserId(r)
	toId := r.FormValue("toId")

	_, err := app.DB.Exec("INSERT INTO requests (from_id, to_id) VALUES ($1, $2)", fromId, toId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func (app *App) GetConnectionRequests(w http.ResponseWriter, r *http.Request) {
	userId := middleware.GetUserId(r)
	query := `SELECT from_id FROM requests WHERE to_id = $1 AND processed = FALSE`
	rows, err := app.DB.Query(query, userId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			http.Error(w, "failed to scan connection requests", http.StatusInternalServerError)
			return
		}
		ids = append(ids, id)
	}

	if err = rows.Err(); err != nil {
		http.Error(w, "error occurred during rows iteration", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(models.IdList{Ids: ids})
	if err != nil {
		http.Error(w, "failed to encode JSON", http.StatusInternalServerError)
		return
	}
}

func (app *App) AcceptRequest(w http.ResponseWriter, r *http.Request) {
	toId := middleware.GetUserId(r)
	fromId := r.FormValue("toId")

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	smallId, largeId := util.OrderPair(numToId, numFromId)

	_, err = app.DB.Exec("INSERT INTO connections (user_id1, user_id2) VALUES ($1, $2)", smallId, largeId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	_, err = app.DB.Exec("UPDATE requests SET processed = TRUE WHERE from_id = $1 AND to_id = $2", toId, fromId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func (app *App) DeclineRequest(w http.ResponseWriter, r *http.Request) {
	toId := middleware.GetUserId(r)
	fromId := r.FormValue("toId")

	numToId, err := strconv.Atoi(toId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	numFromId, err := strconv.Atoi(fromId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	smallId, largeId := util.OrderPair(numToId, numFromId)

	_, err = app.DB.Exec("UPDATE requests SET processed = TRUE WHERE from_id = $1 AND to_id = $2", smallId, largeId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	_, err = app.DB.Exec("UPDATE mathces SET rejected = TRUE WHERE user_id1 = $1 AND user_id2 = $2", smallId, largeId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

}

package util

import (
	"encoding/json"
	"fmt"
	"matchMe/pkg/models"
	"net/http"
)

func HandleError(w http.ResponseWriter, message string, statusCode int, err error) {
	newError := models.Error{
		Message:    message,
		StatusCode: statusCode,
	}

	if err != nil {
		fmt.Printf("Error: %v\n", err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(newError)

}

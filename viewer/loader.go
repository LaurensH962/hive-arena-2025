package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"github.com/gorilla/websocket"
)

import . "hive-arena/common"

func parseJSON(bytes []byte) *PersistedGame {
	var game PersistedGame
	err := json.Unmarshal(bytes, &game)

	if err != nil {
		fmt.Println(err)
		return nil
	}
	return &game
}

func GetURL(url string) *PersistedGame {
	res, err := http.Get(url)
	if err != nil {
		fmt.Println(err)
		return nil
	}

	body, err := io.ReadAll(res.Body)
	res.Body.Close()

	if res.StatusCode > 299 {
		fmt.Printf("Response failed with status code: %d and\nbody: %s\n", res.StatusCode, body)
		return nil
	}

	if err != nil {
		fmt.Println(err)
		return nil
	}

	return parseJSON(body)
}

func GetFile(path string) *PersistedGame {
	bytes, err := os.ReadFile(path)
	if err != nil {
		fmt.Println(err)
		return nil
	}

	return parseJSON(bytes)
}

func request(url string) string {

	resp, err := http.Get(url)
	if err != nil {
		fmt.Println("Could not get " + url)
		os.Exit(1)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	body := string(bodyBytes)

	if resp.StatusCode != 200 {
		fmt.Println("Error:", body)
		os.Exit(1)
	}

	return body
}

func startWebSocket(host string, id string) *websocket.Conn {

	url := "ws://" + host + fmt.Sprintf("/ws?id=%s", id)

	ws, _, err := websocket.DefaultDialer.Dial(url, nil)

	if err != nil {
		fmt.Println("Websocket error: ", err)
		os.Exit(1)
	}

	return ws
}

func getState(host string, id string, token string) GameState {

	url := "http://" + host + fmt.Sprintf("/game?id=%s&token=%s", id, token)
	body := request(url)

	var response GameState
	json.Unmarshal([]byte(body), &response)

	return response
}

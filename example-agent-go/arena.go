package main

import (
	"fmt"
	"net/http"
	"encoding/json"
	"os"
	"io"
	"strconv"
)

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

type JoinResponse struct {
	Id uint
	Token string
}

func joinGame(host string, id uint, name string) JoinResponse {

	url := host + fmt.Sprintf("join?id=%d&name=%s", id, name)
	body := request(url)

	var response JoinResponse
	json.Unmarshal([]byte(body), &response)

	return response
}

type Entity struct {
	Type string
	Hp uint
	Player uint
}

type Hex struct {
	Terrain string
	Resources uint
	Influence uint
	Entity *Entity
}

type GameState struct {
	NumPlayers uint
	Turn uint
	Hexes map[string]Hex
	PlayerResources []uint
	lastInfluenceChange uint
	Winners map[uint]bool
	GameOver bool
}

func getState(host string, id uint, token string) GameState {

	url := host + fmt.Sprintf("game?id=%d&token=%s", id, token)
	body := request(url)

	var response GameState
	json.Unmarshal([]byte(body), &response)

	return response
}

func main() {

	if len(os.Args) <= 3 {
		fmt.Println("Usage: ./agent <host> <gameid> <name>")
		os.Exit(1)
	}

	host := os.Args[1]
	idStr, _ := strconv.Atoi(os.Args[2])
	id := uint(idStr)
	name := os.Args[3]

	gameInfo := joinGame(host, id, name)
	state := getState(host, id, gameInfo.Token)

	fmt.Println(state)
}

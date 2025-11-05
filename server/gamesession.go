package main

import (
	"encoding/json"
	"fmt"
	"github.com/gorilla/websocket"
	"log"
	"maps"
	"math/rand"
	"slices"
	"sync"
	"time"
)

import . "hive-arena/common"

const TurnTimeout = 5 * time.Second

type Player struct {
	ID    int
	Name  string
	Token string
}

type Turn struct {
	Orders []*Order
	State  *GameState
}

type GameSession struct {
	mutex sync.Mutex

	ID           string
	Map          string
	CreatedDate  time.Time
	AdminToken   string
	PlayerTokens []string
	Players      []Player
	State        *GameState

	PendingOrders [][]*Order
	History       []Turn

	Sockets []*websocket.Conn
}

func generateTokens(count int) []string {
	tokens := make(map[string]bool)

	for len(tokens) < count {
		tokens[fmt.Sprintf("%x", rand.Uint64())] = true
	}

	return slices.Collect(maps.Keys(tokens))
}

func NewGameSession(id string, players int, mapname string, mapdata MapData) *GameSession {

	tokens := generateTokens(players + 1)

	return &GameSession{
		ID:           id,
		Map:          mapname,
		CreatedDate:  time.Now(),
		AdminToken:   tokens[0],
		PlayerTokens: tokens[1:],
		State:        NewGameState(mapdata, players),
	}
}

func (game *GameSession) IsFull() bool {
	return len(game.Players) == game.State.NumPlayers
}

func (game *GameSession) AddPlayer(name string) *Player {
	game.mutex.Lock()
	defer game.mutex.Unlock()

	if game.IsFull() {
		return nil
	}

	id := len(game.Players)
	player := Player{id, name, game.PlayerTokens[id]}

	game.Players = append(game.Players, player)

	if game.IsFull() {
		game.BeginTurn()
	}

	return &player
}

func (game *GameSession) Player(token string) *Player {
	game.mutex.Lock()
	defer game.mutex.Unlock()

	playerid := slices.Index(game.PlayerTokens, token)
	if playerid < 0 {
		return nil
	}
	return &game.Players[playerid]
}

func (game *GameSession) GetView(token string) *GameState {
	game.mutex.Lock()
	defer game.mutex.Unlock()

	playerid := slices.Index(game.PlayerTokens, token)
	if playerid < 0 {
		return nil
	}

	return game.State.PlayerView(playerid)
}

func (game *GameSession) BeginTurn() {

	game.notifySockets()

	if game.State.GameOver {
		return
	}

	game.PendingOrders = make([][]*Order, game.State.NumPlayers)

	currentTurn := game.State.Turn
	time.AfterFunc(TurnTimeout, func() {
		game.mutex.Lock()
		defer game.mutex.Unlock()

		if game.State.Turn == currentTurn {
			game.processTurn()
		}
	})
}

func (game *GameSession) SetOrders(playerid int, orders []*Order) {
	game.mutex.Lock()
	defer game.mutex.Unlock()

	game.PendingOrders[playerid] = orders

	log.Printf("Player %s posted orders in game %s", game.Players[playerid].Name, game.ID)

	if game.allPlayed() {
		game.processTurn()
	}
}

func (game *GameSession) allPlayed() bool {
	for _, orders := range game.PendingOrders {
		if orders == nil {
			return false
		}
	}
	return true
}

func (game *GameSession) processTurn() {
	log.Printf("Processing orders for game %s, turn %d", game.ID, game.State.Turn)

	results, _ := game.State.ProcessOrders(game.PendingOrders)
	game.History = append(game.History, Turn{results, game.State.Clone()})

	game.BeginTurn()
}

func (game *GameSession) RegisterWebSocket(socket *websocket.Conn) {
	game.mutex.Lock()
	defer game.mutex.Unlock()

	game.Sockets = append(game.Sockets, socket)
}

func (game *GameSession) notifySockets() {
	message, _ := json.Marshal(map[string]any{
		"turn":     game.State.Turn,
		"gameOver": game.State.GameOver,
	})

	for _, socket := range game.Sockets {
		socket.WriteMessage(websocket.TextMessage, message)

		if game.State.GameOver {
			socket.Close()
		}
	}
}

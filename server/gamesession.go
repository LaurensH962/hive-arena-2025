package main

import (
	"encoding/json"
	"fmt"
	"log"
	"maps"
	"math/rand"
	"os"
	"slices"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	. "hive-arena/common"
)

const MinTurnDuration = 500 * time.Millisecond
const TurnTimeout = 2 * time.Second

type Player struct {
	ID    int
	Name  string
	Token string
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
	state := NewGameState(mapdata, players)

	return &GameSession{
		ID:           id,
		Map:          mapname,
		CreatedDate:  time.Now(),
		AdminToken:   tokens[0],
		PlayerTokens: tokens[1:],
		State:        state,
		History:      []Turn{{Orders: nil, State: state.Clone()}},
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

	if !DevMode {
		time.Sleep(MinTurnDuration)
	}

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
	game.History = append(game.History, Turn{Orders: results, State: game.State.Clone()})

	if game.State.GameOver {
		log.Printf("Game %s is over", game.ID)
		game.persist()
	}

	game.BeginTurn()
}

func (game *GameSession) RegisterWebSocket(socket *websocket.Conn) {
	game.mutex.Lock()
	defer game.mutex.Unlock()

	game.Sockets = append(game.Sockets, socket)

	if game.IsFull() {
		game.notifySocket(socket)
	}
}

func (game *GameSession) notifySocket(socket *websocket.Conn) {
	message, _ := json.Marshal(map[string]any{
		"turn":     game.State.Turn,
		"gameOver": game.State.GameOver,
	})

	socket.WriteMessage(websocket.TextMessage, message)

	if game.State.GameOver {
		socket.Close()
	}
}

func (game *GameSession) notifySockets() {
	for _, socket := range game.Sockets {
		game.notifySocket(socket)
	}
}

func (game *GameSession) persist() {
	date, _ := game.CreatedDate.MarshalText()
	path := fmt.Sprintf("%s/%s-%s-%s.json",
		HistoryDir,
		date,
		game.ID,
		game.Map,
	)

	players := make([]string, len(game.Players))
	for i, player := range game.Players {
		players[i] = player.Name
	}

	info := PersistedGame{
		Id:          game.ID,
		Map:         game.Map,
		CreatedDate: game.CreatedDate,
		Players:     players,
		History:     game.History,
	}

	file, _ := os.Create(path)
	defer file.Close()

	json.NewEncoder(file).Encode(info)
}

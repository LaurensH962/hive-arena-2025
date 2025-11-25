package main

import (
	"fmt"
	"math/rand"
	"os"

	. "hive-arena/common"
)

var dirs = []Direction{E, SE, SW, W, NW, NE}

func think(state *GameState, player int) []Order {

	var orders []Order

	// check GameState.NumPlayers & select strategy based on that

	for coords, hex := range state.Hexes {
		unit := hex.Entity

		if unit != nil && unit.Type == BEE && unit.Player == player {
			fmt.Println(coords, unit)
			orders = append(orders, Order{
				Type:      MOVE,
				Coords:    coords,
				Direction: dirs[rand.Intn(len(dirs))],
			})
		}
	}

	return orders
}

func main() {
	if len(os.Args) <= 3 {
		fmt.Println("Usage: ./agent <host> <gameid> <name>")
		os.Exit(1)
	}

	host := os.Args[1]
	id := os.Args[2]
	name := os.Args[3]

	Run(host, id, name, think)
}

package main

import (
	"fmt"
	// "math/rand"
	"os"

	. "hive-arena/common"
)

//var dirs = []Direction{E, NE, SW, W, NW, NE}

func think(state *GameState, player int) []Order {

	as := EnsureAgentMemory(player)
	as.UpdateFromGameState(state, player)
	fmt.Print(as.DetailedString())
	// var orders []Order
	orders := commands(state, player, as)
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

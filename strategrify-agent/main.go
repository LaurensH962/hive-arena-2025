package main

import (
	"fmt"
	"math/rand"
	"os"

	. "hive-arena/common"
)

//var dirs = []Direction{E, NE, SW, W, NW, NE}

func think(state *GameState, player int) []Order {

	as := EnsureAgentMemory(player)
	as.UpdateFromGameState(state, player)
	fmt.Print(as.DetailedString())
	var orders []Order
	// orders := commands(state, player)

	// Use a persistent AgentMemory so we keep discovered info across turns.

	// check GameState.NumPlayers & select strategy based on that AT SOME POINT LOL

	for _, b := range as.MyBees {
		// If carrying a flower, move back to nearest own hive and forage (deposit) when adjacent
		if b.HasFlower {
			// find nearest own hive
			var nearest Coords
			foundHive := false
			bestDist := 0
			for _, h := range as.Hives[player] {
				d := b.Coords.Distance(h)
				if !foundHive || d < bestDist {
					foundHive = true
					bestDist = d
					nearest = h
				}
			}

			// if adjacent to a hive, deposit via FORAGE
			deposited := false
			if foundHive {
				if bestDist == 1 {
					orders = append(orders, Order{Type: FORAGE, Coords: b.Coords})
					deposited = true
				}
			}

			if deposited {
				continue
			}

			// otherwise move towards nearest hive if we know one
			//PATHFIDER HERE
// ///////////////////////////////////////////////////////////////////
			if foundHive {
				if dir, ok := as.BestDirectionTowards(b.Coords, nearest); ok {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
					continue
				}
			}

			// fallback random move
			orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dirs[rand.Intn(len(dirs))]})
			continue
		}
////////////////////////////////////////////////////////////////////////
		// Not carrying a flower: if standing on a field with resources, forage (pick)
		if _, ok := as.Flowers[b.Coords]; ok {
			orders = append(orders, Order{Type: FORAGE, Coords: b.Coords})
			continue
		}

		// otherwise move toward nearest visible flower
		target, ok := as.GetNearestFlower(b.Coords)
		if ok {
			if dir, ok2 := as.BestDirectionTowards(b.Coords, target); ok2 {
				orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
				continue
			}
		}

		// fallback to random move
		orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dirs[rand.Intn(len(dirs))]})
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

package main

import (
	"fmt"
	. "hive-arena/common"
)

// create a new function to spawn more hives
func BuildHivesOrders(state *GameState, player int, as *AgentState) []Order {
	orders := []Order{}

	hives := as.Hives[player]
	if len(hives) == 1 {
		// if bee finds a batch of flower beds that are next to each other
		// and they are => 4 then if we have 12 flowers then build hive
		// next to flowewr patch

		resources := int(state.PlayerResources[player])

		if resources >= 12 {
				
			// here i choose which bee is in the best position to spawn the hive
			// if they are not then check which bee is closest in spawn
			// path find to the location and build hive
			bee := as.MyBees[0]
			target := bee.Coords

			//newHive := target
			//as.Hives[player] = append(as.Hives[player], target)
			//change the order
			orders = append(orders, Order{Type: BUILD_HIVE, Coords: target})
			resources -= int(12)
			fmt.Println("--------------- target -------------------", target)
			// next to the player so a neighbour tile
			// need to also check that the tile doesnt have anything in there and it is free to build
		}	
	}
	return orders
}


func BuildSpawnOrders(state *GameState, player int, as *AgentState) []Order {
	const maxBees = 7
	orders := []Order{}

	// count current bees (authoritative from state)
	beeCount := 0
	for _, hex := range state.Hexes {
		if hex.Entity != nil && hex.Entity.Type == BEE && hex.Entity.Player == player {
			beeCount++
		}
	}

	if beeCount >= maxBees {
		return orders
	}

	resources := int(state.PlayerResources[player])

	hives := as.Hives[player]
	// if len(hives) == 0 {
	// 	for coords, hex := range state.Hexes {
	// 		if hex.Entity != nil && hex.Entity.Type == HIVE && hex.Entity.Player == player {
	// 			hives = append(hives, coords)
	// 		}
	// 	}
	// }

	spawnDirs := []Direction{E, NE, NW, W, SW, SE}


	//spawn as long as we have resources
	for _, hive := range hives {
		if beeCount >= maxBees || resources < int(BEE_COST) {
			break
		}

		for _, dir := range spawnDirs {
			if resources < int(BEE_COST) || beeCount >= maxBees {
				break
			}
			target := hive.Neighbour(dir)
			hex, ok := state.Hexes[target]
			if !ok {
				continue
			}
			if !hex.Terrain.IsWalkable() {
				continue
			}
			if hex.Entity != nil {
				continue
			}

			orders = append(orders, Order{Type: SPAWN, Coords: hive, Direction: dir})
			resources -= int(BEE_COST)
			beeCount++
		}
	}

	return orders
}

package main

import (
	// "fmt"
	. "hive-arena/common"
)

// BuildHivesOrders checks each bee to see if it should build a new hive.
// A bee bevomes the new queen of a hive when:
//   - Total player resources >= 24
//   - Bee sees > 3 flower hexes within visible range
//   - Bee is > 10 hexes away from nearest existing hive
func BuildHivesOrders(state *GameState, player int, as *AgentState) []Order {
	orders := []Order{}

	resources := int(state.PlayerResources[player])
	if resources < 12 {
		return orders // not enough resources
	}

	hives := as.Hives[player]
	if len(hives) >= 2 {
		return orders 
	}

	// Check each bee to see if you ares a princess that wants to become a queen
	for _, bee := range as.MyBees {
		flowerCount := 0
		flowerResources := 0
		for flowerCoord, resources := range as.Flowers {
			if bee.Coords.Distance(flowerCoord) <= 4 {
				flowerCount++
				flowerResources += int(resources)
			}
		}

		if flowerCount < 4 || flowerResources < 24 {
			continue
		}

		nearestHiveDist := -1
		for _, hive := range hives {
			dist := bee.Coords.Distance(hive)
			if nearestHiveDist == -1 || dist < nearestHiveDist {
				nearestHiveDist = dist
			}
		}
		if nearestHiveDist < 10 {
			continue 
		}

		// you are the new queen. ALL HAIL THE QUEEN!
		orders = append(orders, Order{Type: BUILD_HIVE, Coords: bee.Coords})
		resources -= 12
		break
	}

	return orders
}


	// orders := []Order{}

	// hives := as.Hives[player]
	// if len(hives) == 1 {
	// 	// if bee finds a batch of flower beds that are next to each other
	// 	// and they are => 4 then if we have 12 flowers then build hive
	// 	// next to flowewr patch

	// 	resources := int(state.PlayerResources[player])

	// 	if resources >= 12 {
				
	// 		// here i choose which bee is in the best position to spawn the hive
	// 		// if they are not then check which bee is closest in spawn
	// 		// path find to the location and build hive
	// 		bee := as.MyBees[0]
	// 		target := bee.Coords

	// 		//newHive := target
	// 		//as.Hives[player] = append(as.Hives[player], target)
	// 		//change the order
	// 		orders = append(orders, Order{Type: BUILD_HIVE, Coords: target})
	// 		resources -= int(12)
	// 		fmt.Println("--------------- target -------------------", target)
	// 		// next to the player so a neighbour tile
	// 		// need to also check that the tile doesnt have anything in there and it is free to build
	// 	}	
	// }
	// return orders





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

package main

import (
	//"fmt"
	//"math/rand"
	//"os"

	. "hive-arena/common"
)

var dirs = []Direction{E, NE, SW, W, NW, NE}

	// check GameState.NumPlayers & select strategy based on that
func commands(state *GameState, player int) []Order {
	var orders []Order
	for coords, hex := range state.Hexes {
		unit := hex.Entity
		//fmt.Println(coords, unit) // debugging print, print out the coordinates and the unit's contents
		if hex.Terrain == FIELD && hex.Resources != 0 && unit != nil && unit.Type == BEE && unit.Player == player && unit.HasFlower == false {
			orders = append(orders, Order {
				Type:	FORAGE,
				Coords:	coords,
				// also add the field coordinates to the struct??
			})
		}
		if unit != nil && unit.Type == BEE && unit.Player == player {
			for _, dir := range dirs {
				next := coords.Neighbour(dir)
            	nextHex, ok := state.Hexes[next]
	
				if ok && (nextHex.Terrain == EMPTY || nextHex.Terrain == FIELD) {
					orders = append(orders, Order{
						Type:      MOVE,
						Coords:    coords,
						Direction: dir,
					})
					break
				}
				if ok && (nextHex.Terrain == ROCK || (nextHex.Entity != nil && nextHex.Entity.Type == WALL)) {
					continue
				}
			}
		}
	}
	return orders
}

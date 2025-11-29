package main

import (
	// "fmt"
	"math/rand"
	//"os"

	. "hive-arena/common"
)

var dirs = []Direction{E, NE, SW, W, NW, NE}


func commands(state *GameState, player int, as *AgentState) []Order {
	var orders []Order

	// try to spawn new bees first
	orders = append(orders, BuildHivesOrders(state, player, as)...)
	orders = append(orders, BuildSpawnOrders(state, player, as)...)
	// here spawn new hives --------------------------------///////////////////////////////////////////
	//////////////////////////////////////// EMILIA

	// check GameState.NumPlayers & select strategy based on that AT SOME POINT LOL

	for _, b := range as.MyBees {

//// FIRST CHECK IF BEE ALREADY HAS FLOWER ////////

		if b.HasFlower {

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

			// if next to a hive, deposit flower
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

			if foundHive {
				path, ok := as.find_path(b.Coords, nearest)
				if !ok || len(path) <= 1 {
					if dir, ok2 := as.BestDirectionTowards(b.Coords, nearest); ok2 {
						// if there's a wall in that direction, attack it; otherwise move
						target := b.Coords.Neighbour(dir)
						if IsWallAt(as, target) {
							orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: dir})
							continue
						}
						if _, ok3 := IsValidMoveTarget(as, b.Coords, dir); ok3 {
							orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
							continue
						}
					}
				} else {
					if dir, ok4 := as.BestDirectionTowards(b.Coords, path[1]); ok4 {
						orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
					}
					continue
				}
			}

			maxTries := 10
			var chosen Direction
			found := false
			for i := 0; i < maxTries; i++ {
				d := dirs[rand.Intn(len(dirs))]
				if _, ok := IsValidMoveTarget(as, b.Coords, d); ok {
					chosen = d
					found = true
					break
				}
			}
			if found {
				target := b.Coords.Neighbour(chosen)
				if IsWallAt(as, target) {
					orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: chosen})
				} else {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: chosen})
				}
			} else {
				d2 := dirs[rand.Intn(len(dirs))]
				target := b.Coords.Neighbour(d2)
				if IsWallAt(as, target) {
					orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: d2})
				} else {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: d2})
				}
			}
			continue
		}


///// BEE IS NOT CARRYING FLOWER ////
		// Not carrying a flower: if bee is already standing on a field with resources, forage (pick)
		if _, ok := as.Flowers[b.Coords]; ok {
			orders = append(orders, Order{Type: FORAGE, Coords: b.Coords})
			continue
		}
		// otherwise move toward nearest visible flower
		target, ok := as.GetNearestFlower(b.Coords)
		if ok {
			/// HOX this action should be implemented wisely >:) -> currently builds walls too often and in inconsiderate places
/* 			if state.Turn%5 == 0 {
				// choose a valid neighbouring direction to build a wall
				for _, wd := range dirs {
					if _, ok := IsValidMoveTarget(as, b.Coords, wd); ok {
						orders = append(orders, Order{Type: BUILD_WALL, Coords: b.Coords, Direction: wd})
						break
					}
				}
			} */
			path, ok2 := as.find_path(b.Coords, target)
			// If we have no usable path, try greedy best-direction towards target -> just the shortest distance path
			if !ok2 || len(path) <= 1 {
				if dir, ok3 := as.BestDirectionTowards(b.Coords, target); ok3 {
						// attack a wall if present, otherwise move
						targetCoords := b.Coords.Neighbour(dir)
						if IsWallAt(as, targetCoords){
							orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: dir})
							continue
						}
						if _, ok4 := IsValidMoveTarget(as, b.Coords, dir); ok4 {
							orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
							continue
						}
				}
			} else {
				if dir, ok := as.BestDirectionTowards(b.Coords, path[1]); ok {
						// attack a wall if present, otherwise move
						targetCoords := b.Coords.Neighbour(dir)
						if IsWallAt(as, targetCoords) {
							orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: dir})
						} else if _, okv := IsValidMoveTarget(as, b.Coords, dir); okv {
							orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
						}
				}
				continue
			}
		}
		
		// fallback random move -- try a few times until we find a valid move
		{
			maxTries := 10
			var chosen Direction
			found := false
			for i := 0; i < maxTries; i++ {
				d := dirs[rand.Intn(len(dirs))]
				if _, ok := IsValidMoveTarget(as, b.Coords, d); ok {
					chosen = d
					found = true
					break
				}
			}
			if found {
				target := b.Coords.Neighbour(chosen)
				if IsWallAt(as, target) {
					orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: chosen})
				} else {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: chosen})
				}
			} else {
				d2 := dirs[rand.Intn(len(dirs))]
				target := b.Coords.Neighbour(d2)
				if IsWallAt(as, target) {
					orders = append(orders, Order{Type: ATTACK, Coords: b.Coords, Direction: d2})
				} else {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: d2})
				}
			}
		}
	}
	return orders
}

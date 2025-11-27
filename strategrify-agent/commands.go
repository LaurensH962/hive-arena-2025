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
	orders = append(orders, BuildSpawnOrders(state, player, as)...)

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
				orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: chosen})
			} else {
				orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dirs[rand.Intn(len(dirs))]})
				//ATACK
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
			path, ok2 := as.find_path(b.Coords, target)
			// If we have no usable path, try greedy best-direction towards target -> just the shortest distance path
			if !ok2 || len(path) <= 1 {
				if dir, ok3 := as.BestDirectionTowards(b.Coords, target); ok3 {
					if _, ok4 := IsValidMoveTarget(as, b.Coords, dir); ok4 {
						orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
						continue
					}
				}
			} else {
				if dir, ok := as.BestDirectionTowards(b.Coords, path[1]); ok {
					if _, okv := IsValidMoveTarget(as, b.Coords, dir); okv {
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
				orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: chosen})
			} else {
				orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dirs[rand.Intn(len(dirs))]})
				//ATTACK arghhhh
			}
		}
	}
	return orders
}

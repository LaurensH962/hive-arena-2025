package main

import (
	"fmt"
	"math/rand"
	//"os"

	. "hive-arena/common"
)

var dirs = []Direction{E, NE, SW, W, NW, NE}

// check GameState.NumPlayers & select strategy based on that
func commands(state *GameState, player int, as *AgentState) []Order {
	var orders []Order
	// check GameState.NumPlayers & select strategy based on that AT SOME POINT LOL

	for _, b := range as.MyBees {

//// FIRST CHECK IF BEE ALREADY HAS FLOWER ////////

		// if yes: move back to nearest own hive and forage (deposit) when adjacent
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
			// when flower deposit, go to next bee :)
			if deposited {
				continue
			}

			// otherwise move towards nearest hive if we know one
	// EMILLIAS PATHFINDER WILL GO HERE
			if foundHive {
				path, ok := as.find_path(b.Coords, nearest)
				fmt.Println("i am here")
				fmt.Println("set:", path)
				fmt.Println("get:", path[1])
				fmt.Println("len:", len(path))
				if !ok {
					fmt.Println("i am here")
					if dir, ok2 := as.BestDirectionTowards(b.Coords, nearest); ok2 {
						if _, ok3 := IsValidMoveTarget(as, b.Coords, dir); ok3 {
							orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
							continue
						}
					}
				}
				if dir, ok4 := as.BestDirectionTowards(b.Coords, path[1]); ok4 {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
				}
				continue
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
			// If we have no usable path, try greedy best-direction towards target
			if !ok2 || len(path) <= 1 {
				if dir, ok3 := as.BestDirectionTowards(b.Coords, target); ok3 {
					if _, ok4 := IsValidMoveTarget(as, b.Coords, dir); ok4 {
						orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
						continue
					}
				}
			} else {
				// path is long enough, step towards next node on path
				if dir, ok := as.BestDirectionTowards(b.Coords, path[1]); ok {
					if _, okv := IsValidMoveTarget(as, b.Coords, dir); okv {
						orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
					}
				}
				continue
			}
		}
		//maybe better move to oposite direction than hive
		
		
		// fallback random move -- try a few times until we find a valid target
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
				//ATACK
			}
		}
	}
	return orders
}

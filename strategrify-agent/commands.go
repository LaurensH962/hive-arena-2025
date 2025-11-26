package main

import (
	//"fmt"
	"math/rand"
	//"os"

	. "hive-arena/common"
)

var dirs = []Direction{E, NE, SW, W, NW, NE}

	// check GameState.NumPlayers & select strategy based on that
func commands(state *GameState, player int,as *AgentState) []Order {
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
				if dir, ok := as.BestDirectionTowards(b.Coords, nearest); ok {
					orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
					continue
				}
			}

			// fallback random move
			orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dirs[rand.Intn(len(dirs))]})
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
	// EMILIAS PATHFINDER WILL GO HERE
			if dir, ok2 := as.BestDirectionTowards(b.Coords, target); ok2 {
				orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dir})
				continue
			}
		}
		//maybe better move to oposite direction than hive
		orders = append(orders, Order{Type: MOVE, Coords: b.Coords, Direction: dirs[rand.Intn(len(dirs))]})
	}
	return orders
}

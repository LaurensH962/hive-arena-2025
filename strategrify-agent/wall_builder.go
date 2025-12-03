package main

import (
	"fmt"
	. "hive-arena/common"
)

// BuildWallOrders: assign a single bee to DEFENDER role once enemy hives discovered,
// then have that bee build walls near enemy hives.
// - Once an enemy hive is found, assign the first available non-carrying bee as DEFENDER
// - Only the DEFENDER bee attempts to build walls
// - The defender pathfinds to anchor positions (2 hexes away from enemy hive)
// - When on anchor with resources, builds wall toward the hive
// - Otherwise moves toward an anchor position
func BuildWallOrders(state *GameState, player int, as *AgentState) []Order {
	orders := []Order{}

	// Check if we have discovered any enemy hives
	hasEnemyHives := false
	for owner := range as.Hives {
		if owner != player {
			hasEnemyHives = true
			break
		}
	}

	// If no enemy hives discovered yet, do nothing
	if !hasEnemyHives {
		return orders
	}

	// Find or assign the DEFENDER bee
	var defenderID string
	var defenderBee *UnitInfo

	// First, check if we already have a DEFENDER assigned
	for id, tb := range as.TrackedBees {
		if tb.Role == RoleDefender {
			defenderID = id
			// Find the bee at or near its last position
			for i, b := range as.MyBees {
				if b.Coords == tb.Last || (tb.LastSeenTurn == as.Turn && b.Coords == tb.Last) {
					defenderBee = &as.MyBees[i]
					// Update the tracked bee's last seen position
					tb.Last = b.Coords
					tb.LastSeenTurn = as.Turn
					break
				}
			}
			break
		}
	}

	// If no DEFENDER exists, assign one from available non-carrying bees
	if defenderID == "" {
		for i, b := range as.MyBees {
			if !b.HasFlower {
				// Create a new tracked bee with DEFENDER role
				newID := fmt.Sprintf("bee_%d", as.NextTrackedID)
				as.NextTrackedID++
				as.TrackedBees[newID] = &TrackedBee{
					ID:           newID,
					Last:         b.Coords,
					Role:         RoleDefender,
					LastSeenTurn: as.Turn,
				}
				defenderID = newID
				defenderBee = &as.MyBees[i]
				fmt.Printf("WallBuilder: Assigned DEFENDER role to bee at %v (ID: %s)\n", b.Coords, newID)
				break
			}
		}
	}

	// If we still don't have a defender, return (all bees are carrying flowers)
	if defenderBee == nil || defenderID == "" {
		return orders
	}

	// Update BeeRoles map with current position
	as.BeeRoles[defenderBee.Coords] = RoleDefender

	// The DEFENDER bee should work on building walls near enemy hives
	// Try each enemy hive and direction to find a target
	reservation := make(map[Coords]bool)

	for owner, hiveList := range as.Hives {
		if owner == player {
			continue
		}
		
		for _, hive := range hiveList {
			// try every direction outward from hive
			for dir := range DirectionToOffset {
				// mid is tile adjacent to hive; wall will be placed here
				mid := hive.Neighbour(dir)
				// anchor is the tile the bee must stand on to build into mid
				anchor := mid.Neighbour(dir)

				// skip if already reserved
				if reservation[mid] {
					continue
				}

				// both tiles must exist in the authoritative state
				midHex, ok1 := state.Hexes[mid]
				anchorHex, ok2 := state.Hexes[anchor]
				if !ok1 || !ok2 {
					continue
				}

				// must be walkable
				if !midHex.Terrain.IsWalkable() || !anchorHex.Terrain.IsWalkable() {
					continue
				}

				// mid must be empty (no entity) at planning time
				if midHex.Entity != nil {
					continue
				}

				// anchor is allowed to be occupied only if it's the defender itself
				if anchorHex.Entity != nil && anchorHex.Entity.Player != defenderBee.Player {
					continue
				}

				// skip if there's already a recorded wall in memory
				if as.IsWall(mid) {
					continue
				}

				// pathfind defender to anchor
				path, ok := as.find_path(*defenderBee, anchor)
				if !ok || len(path) == 0 {
					continue
				}

				// if defender is already on anchor, attempt build (if resources available)
				if defenderBee.Coords == anchor {
					if int(state.PlayerResources[player]) >= int(WALL_COST) {
						// compute direction from bee->mid
						var dirToMid Direction
						found := false
						for d := range DirectionToOffset {
							if defenderBee.Coords.Neighbour(d) == mid {
								dirToMid = d
								found = true
								break
							}
						}
						if !found {
							continue
						}

						// final safety check: mid still empty in state
						if state.Hexes[mid] != nil && state.Hexes[mid].Entity == nil {
							orders = append(orders, Order{Type: BUILD_WALL, Coords: defenderBee.Coords, Direction: dirToMid})
							reservation[mid] = true
							fmt.Printf("WallBuilder: DEFENDER (%s) at %v BUILD_WALL toward hive %v (into mid %v)\n", defenderID, defenderBee.Coords, hive, mid)
							return orders
						}
					}
					// else (insufficient resources) skip
					continue
				}

				// otherwise issue single-step MOVE along path toward anchor
				if len(path) > 1 {
					next := path[1]
					if dirMove, ok := as.BestDirectionTowards(defenderBee.Coords, next); ok {
						if _, ok2 := IsValidMoveTarget(as, defenderBee.Coords, dirMove); ok2 {
							orders = append(orders, Order{Type: MOVE, Coords: defenderBee.Coords, Direction: dirMove})
							fmt.Printf("WallBuilder: DEFENDER (%s) MOVE from %v toward anchor %v (next=%v, hive=%v)\n", defenderID, defenderBee.Coords, anchor, next, hive)
							return orders
						}
					}
				}

				// If we couldn't move along the path, try any valid direction toward anchor
				if dirMove, ok := as.BestDirectionTowards(defenderBee.Coords, anchor); ok {
					if _, ok2 := IsValidMoveTarget(as, defenderBee.Coords, dirMove); ok2 {
						orders = append(orders, Order{Type: MOVE, Coords: defenderBee.Coords, Direction: dirMove})
						fmt.Printf("WallBuilder: DEFENDER (%s) MOVE from %v toward anchor %v (hive=%v)\n", defenderID, defenderBee.Coords, anchor, hive)
						return orders
					}
				}
			}
		}
	}

	return orders
}
package main

import (
	"fmt"
	. "hive-arena/common"
)

type node struct {
	Hex_c Coords
	Prev  *node
	D     int // distance from start
	H     int // estimated distance to goal
	F     int // G + H
}

// checks if the coordinate hex has a wall
func (as *AgentState) IsWall(c Coords) bool {
	for _, w := range as.Walls {
		if w == c {
			return true
		}
	}
	return false
}

//    HasFlower bool

// checks if the coordinate hex has a bee own or opponent
func (as *AgentState) IsBee(c Coords, b UnitInfo) bool {
	for _, w := range as.MyBees {
		if w.Coords == c {
			return true
		}
	}
	for _, w := range as.EnemyBees {
		if w.Coords == c {
			return true
		}
	}
	return false
}

func (as *AgentState) IsHive(c, goal Coords) bool {
	for _, hs := range as.Hives {
		for _, h := range hs {
			if h == c && h != goal{
				return true
			}
		}
	}
	for _, hs := range as.EnemyHives {
		for _, h := range hs {
			if h == c {
				return true
			}
		}
	}
	return false
}

func FindLowestCost(queue []*node) (*node, int) {
	if len(queue) == 0 {
		return nil, -1
	}
	lowest := queue[0]
	lowestVal := queue[0].F
	index := 0

	for i, n := range queue {
		if n.F < lowestVal {
			lowest = n
			lowestVal = n.F
			index = i
		}
	}
	return lowest, index
}

// TODO: add in the path finder that it recognizes enemy bees and tries to be 1 step away from them
// and also the own bee that holds a flower has the right of the way

// gets start and goal coordinates and the map
// returns the path to the goal and true, or
// nil and false if no path is possible

// do we save the path to our memory and check if the path is still valid next turn?
// because walls may rise up or the path may change, might be faster to check if the generated path
// is still available than always to create new path
func (as *AgentState) find_path(b UnitInfo, goal Coords) ([]Coords, bool) {
	start := b.Coords
	bestDist := b.Coords.Distance(goal) // the distance between the start and the goal

	visited := make(map[Coords]int)
	startNode := &node{Hex_c: start, Prev: nil, D: 0, H: bestDist, F: 0 + bestDist}
	queue := []*node{startNode}
	visited[start] = 0

	for len(queue) > 0 {
		current, index := FindLowestCost(queue)
		if current == nil {
			return nil, false
		}
		queue = append(queue[:index], queue[index+1:]...)

		if current.Hex_c == goal {
			var path []Coords
			for n := current; n != nil; n = n.Prev {
				path = append([]Coords{n.Hex_c}, path...)
			}
			return path, true
		}

		for dir := range DirectionToOffset {
			next := current.Hex_c.Neighbour(dir)

			// TODO: bees think they can go through hives
			// they also are way too polite and get stuck so fix that
			// Only allow path on known tiles:
			terrain, ok := as.Map[next]
			if !ok {
				continue
			}
			if terrain == ROCK || as.IsWall(next) == true || as.IsBee(next, b) == true || as.IsHive(next, goal) == true {
				continue
			}
			newDist := current.D + 1
			oldDist, ok := visited[next]
			if !ok || newDist < oldDist {
				visited[next] = newDist
				newEst := next.Distance(goal)
				nextNode := &node{Hex_c: next, Prev: current, D: newDist, H: newEst, F: newDist + newEst}
				queue = append(queue, nextNode)
			}
		}
	}

	return nil, false // no path found
}

func (as *AgentState) scout_goal(b UnitInfo) (Coords, bool) {

	// Use BFS to find the nearest known tile that is adjacent to unexplored territory
	// Use heat map to distinguish between map boundaries and unexplored areas:
	// - Border = unknown tile WITH explored neighbors (dead end, don't scout)
	// - Unexplored frontier = unknown tile with NO explored neighbors (real exploration target)

	start := b.Coords
	visited := make(map[Coords]bool)
	startNode := &node{Hex_c: start, Prev: nil}
	queue := []*node{startNode}
	visited[start] = true

	// Increment heat for current position
	as.ScoutHeatMap[start]++

	// Now do full BFS search
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]

		// Check all neighbors of the current known tile
		for dir := range DirectionToOffset {
			next := current.Hex_c.Neighbour(dir)

			// If neighbor is not in map (unknown/unexplored)
			_, isKnown := as.Map[next]
			if !isKnown {
				// Check if this unknown tile is a border or unexplored frontier
				exploredNeighbors := 0
				for checkDir := range DirectionToOffset {
					checkTile := next.Neighbour(checkDir)
					if _, exists := as.Map[checkTile]; exists {
						// Check if this neighbor has been visited (heat > 0)
						if as.ScoutHeatMap[checkTile] > 0 {
							exploredNeighbors++
						}
					}
				}

				// If this unknown tile has NO explored neighbors, it's a real frontier to explore!
				if exploredNeighbors == 0 {
					return current.Hex_c, true
				}
				// Otherwise it's a border (has explored neighbors), skip it

				continue
			}

			// If neighbor is known and not visited, add to queue to explore further
			if !visited[next] {
				visited[next] = true
				newNode := &node{Hex_c: next, Prev: current}
				queue = append(queue, newNode)
			}
		}
	}

	return start, false
}

func find_scout(as *AgentState) []Order {
	// Find or assign the Scout bee
	var scoutID string
	var scoutBee *UnitInfo
	var path []Coords
	order := []Order{}

	// First, check if we already have a SCOUT assigned
	var foundTrackedScout *TrackedBee
	for id, tb := range as.TrackedBees {
		if tb.Role == RoleScout {
			scoutID = id
			foundTrackedScout = tb
			break
		}
	}

	// If we had a tracked scout, try to find the bee
	if foundTrackedScout != nil {
		// First try to find at last known position (bee might have moved 1 step)
		for i, b := range as.MyBees {
			if b.Coords == foundTrackedScout.Last {
				scoutBee = &as.MyBees[i]
				// Update position
				as.TrackedBees[scoutID].Last = b.Coords
				as.TrackedBees[scoutID].LastSeenTurn = as.Turn
				break
			}
		}

		// If not at last position, search all bees for one that looks like our scout
		// (same bee ID would be ideal, but we don't have that info in UnitInfo)
		if scoutBee == nil && foundTrackedScout.LastSeenTurn == as.Turn {
			for i, b := range as.MyBees {
				if !b.HasFlower && b.Coords.Distance(foundTrackedScout.Last) <= 1 {
					scoutBee = &as.MyBees[i]
					as.TrackedBees[scoutID].Last = b.Coords
					as.TrackedBees[scoutID].LastSeenTurn = as.Turn
					break
				}
			}
		}

		// If still not found, the scout is probably now queen bee
		if scoutBee == nil {
			delete(as.TrackedBees, scoutID)
			scoutID = ""
			foundTrackedScout = nil
		}
	}

	// If no SCOUT exists, assign one from available non-carrying bees
	if scoutID == "" {
		for i, b := range as.MyBees {
			if !b.HasFlower {
				// Create a new tracked bee with SCOUT role
				newID := fmt.Sprintf("bee_%d", as.NextTrackedID)
				as.NextTrackedID++
				newTrackedBee := &TrackedBee{
					ID:           newID,
					Last:         b.Coords,
					Role:         RoleScout,
					LastSeenTurn: as.Turn,
				}
				as.TrackedBees[newID] = newTrackedBee
				scoutID = newID
				scoutBee = &as.MyBees[i]
				break
			}
		}
	}

	// If we still don't have a scout, return (all bees are carrying flowers)
	if scoutBee == nil || scoutID == "" {
		return order
	}

	// okei so we have a scout so use scout algorithm to find the neighbour tile of an unknown tile
	goal, ok := as.scout_goal(*scoutBee)
	if !ok {
		// if we dont get anymore goal then return to become a normal bee
		delete(as.TrackedBees, scoutID)
		return order
	}

	// if we have a goal then find the path for the goal
	path, ok = as.find_path(*scoutBee, goal)
	if !ok {
		return order
	}

	if len(path) > 1 {
		nextStep := path[1]
		if dir, ok := as.BestDirectionTowards(scoutBee.Coords, nextStep); ok {
			order = append(order, Order{Type: MOVE, Coords: scoutBee.Coords, Direction: dir})
		}
	}

	// and finally return the orders
	return order
}

package main

import (
	. "hive-arena/common"
)

type node struct {
    Hex_c	Coords
    Prev	*node
    D       int // distance from start
    H       int // estimated distance to goal
    F       int // G + H
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
            if w.HasFlower == true && b.HasFlower != true {
                return true
            }
            if w.HasFlower == true && b.HasFlower == true {
                return true
            }
        }
    }
    for _, w := range as.EnemyBees {
        if w.Coords == c {
            return true
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
func (as *AgentState) find_path(b UnitInfo, goal Coords, state *GameState) ([]Coords, bool) {
    start := b.Coords
    bestDist := b.Coords.Distance(goal) // the distance between the start and the goal

    visited := make(map[Coords]int)
    startNode := &node{Hex_c: start, Prev: nil, D: 0, H: bestDist, F: 0 + bestDist}
    queue := []*node{startNode}
    visited[start] = 0

    for len(queue) > 0{
        current, index := FindLowestCost(queue)
        if current == nil {
            return nil, false
        }
        queue = append(queue[:index], queue[index + 1:]... )

        if current.Hex_c == goal {
            var path []Coords
            for n := current; n != nil; n = n.Prev {
                path = append([]Coords{n.Hex_c}, path...);
            }
            return path, true
        }

        for dir := range DirectionToOffset {
            next := current.Hex_c.Neighbour(dir)

            // Only allow path on known tiles:
            terrain, ok := as.Map[next]
            if !ok {
                continue
            }
            if terrain == ROCK || as.IsWall(next) == true || as.IsBee(next, b) == true {
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
package main

import (
	. "hive-arena/common"
)

// checks if the coordinate hex has a wall
func (as *AgentState) IsWall(c Coords) bool {
    for _, w := range as.Walls {
        if w == c {
            return true
        }
    }
    return false
}

// checks if the coordinate hex has a bee own or opponent
func (as *AgentState) IsBee(c Coords) bool {
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

// gets start and goal coordinates and the map
// returns the path to the goal and true, or
// nil and false if no path is possible

// do we save the path to our memory and check if the path is still valid next turn?
// because walls may rise up or the path may change, might be faster to check if the generated path
// is still available than always to create new path
func (as *AgentState) find_path(start, goal Coords) ([]Coords, bool) {
    type node struct {
        Hex_c	Coords
        Prev	*node
    }

    visited := make(map[Coords]bool)
    startNode := &node{Hex_c: start, Prev: nil}
    queue := []*node{startNode}
    visited[start] = true

    for len(queue) > 0{
        current := queue[0]
        queue = queue[1:]

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
            if terrain == ROCK || as.IsWall(next) == true || as.IsBee(next) == true{
                continue
            }
			// should we check if there are opponent bees on our path?
            // if so then go around them?

            if !visited[next] {
                visited[next] = true
                nextNode := &node{Hex_c: next, Prev: current}
                queue = append(queue, nextNode)
            }
        }
    }

    return nil, false // no path found
}
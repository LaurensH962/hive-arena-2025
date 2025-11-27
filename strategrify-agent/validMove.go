package main

import (
	//"fmt"
	// "math/rand"
	//"os"
	. "hive-arena/common"
)

func IsValidMoveTarget(as *AgentState, from Coords, dir Direction) (Coords, bool) {
    
	target := from.Neighbour(dir)

    terrain := as.Map[target]

    // terrain must be walkable
    if !terrain.IsWalkable() {
        return target, false
    }

    if hex, ok := as.Hexes[target]; ok && hex.Entity != nil {
        return target, false
    }

    if containsCoords(as.Walls, target) || containsCoords(as.Rocks, target) {
        return target, false
    }

    // check known bees (my and enemy) — they occupy the tile right now
    for _, u := range as.MyBees {
        if u.Coords == target {
            return target, false
        }
    }
    for _, u := range as.EnemyBees {
        if u.Coords == target {
            return target, false
        }
    }

    return target, true
}
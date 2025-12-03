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

// IsWallAt returns true if there is a WALL entity at the given coords
// (convenience helper so callers can react differently to walls).
func IsWallAt(as *AgentState, coords Coords) bool {
    if hex, ok := as.Hexes[coords]; ok && hex.Entity != nil && hex.Entity.Type == WALL {
        return true
    }
    return false
}
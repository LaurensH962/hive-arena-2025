package main

import (
    "fmt"
    "strings"

    . "hive-arena/common"
)

// UnitInfo is a small representation of an entity we care about.
type UnitInfo struct {
    Coords    Coords
    Player    int
    Type      EntityType
    HasFlower bool
}

// AgentState holds the relevant information the agent uses for decision making.
type AgentState struct {
    PlayerID int
    Turn     uint

    Hexes map[Coords]*Hex // visible hexes
    Map   map[Coords]Terrain

    Flowers map[Coords]uint   // field resources
    Rocks   []Coords         // ROCK terrain
    Walls   []Coords         // WALL entities
    Hives   map[int][]Coords // player -> coordinates of hives
    MyBees  []UnitInfo
    EnemyBees []UnitInfo
	EnemyHives map[int][]Coords
    // BeeRoles maps the current coords of each friendly bee to a role
    BeeRoles map[Coords]BeeRole
    // TrackedBees holds persistent tracked bee records so roles survive moves
    TrackedBees map[string]*TrackedBee
    // NextTrackedID is used to generate unique IDs for new tracked bees
    NextTrackedID int
}

// BeeRole is the role assigned to a bee. Simple example roles included.
type BeeRole string

const (
    RoleHarvester BeeRole = "HARVESTER"
    RoleScout     BeeRole = "SCOUT"
    RoleDefender  BeeRole = "DEFENDER"
)

// AgentMemory is the global, persistent agent state that survives across turns.
var AgentMemory *AgentState


// NewAgentState creates a new AgentState from a provided GameState and player id.
func NewAgentState(gs *GameState, player int) *AgentState {
    as := &AgentState{
        PlayerID:  player,
        Turn:      gs.Turn,
        Hexes:     make(map[Coords]*Hex),
        Map:       make(map[Coords]Terrain),
        Flowers:   make(map[Coords]uint),
        Rocks:     []Coords{},
        Walls:     []Coords{},
        Hives:     make(map[int][]Coords),
        MyBees:    []UnitInfo{},
        EnemyBees: []UnitInfo{},
		EnemyHives: make(map[int][]Coords),
        BeeRoles:  make(map[Coords]BeeRole),
        TrackedBees: make(map[string]*TrackedBee),
        NextTrackedID: 0,
    }

    for coords, hex := range gs.Hexes {
        // store hex and terrain
        as.Hexes[coords] = hex
        as.Map[coords] = hex.Terrain

        if hex.Terrain == FIELD && hex.Resources > 0 {
            as.Flowers[coords] = hex.Resources
        }

        if hex.Terrain == ROCK {
            as.Rocks = append(as.Rocks, coords)
        }

        if hex.Entity != nil {
            switch hex.Entity.Type {
            case HIVE:
				if hex.Entity.Player == player {
                	as.Hives[hex.Entity.Player] = append(as.Hives[hex.Entity.Player], coords)
				} else {
					as.EnemyHives[hex.Entity.Player] = append(as.EnemyHives[hex.Entity.Player], coords)
				}
            case WALL:
                as.Walls = append(as.Walls, coords)
            case BEE:
                ui := UnitInfo{Coords: coords, Player: hex.Entity.Player, Type: BEE, HasFlower: hex.Entity.HasFlower}
                if hex.Entity.Player == player {
                    as.MyBees = append(as.MyBees, ui)
                } else {
                    as.EnemyBees = append(as.EnemyBees, ui)
                }
            }
        }
    }

    return as
}

// EnsureAgentMemory initializes the global AgentMemory if not already present.
func EnsureAgentMemory(player int) *AgentState {
    if AgentMemory == nil {
        AgentMemory = &AgentState{
            PlayerID:  player,
            Turn:      0,
            Hexes:     make(map[Coords]*Hex),
            Map:       make(map[Coords]Terrain),
            Flowers:   make(map[Coords]uint),
            Rocks:     []Coords{},
            Walls:     []Coords{},
            Hives:     make(map[int][]Coords),
            MyBees:    []UnitInfo{},
            EnemyBees: []UnitInfo{},
			EnemyHives: make(map[int][]Coords),
            BeeRoles:  make(map[Coords]BeeRole),
            TrackedBees: make(map[string]*TrackedBee),
            NextTrackedID: 0,
        }
    }
    return AgentMemory
}

// TrackedBee represents a persistent record for an observed bee so we can
// maintain role identity across turns even when the bee moves.
type TrackedBee struct {
    ID string
    Last Coords
    Role BeeRole
    LastSeenTurn uint
}

// containsCoords reports whether slice contains coordinate c.
func containsCoords(slice []Coords, c Coords) bool {
    for _, v := range slice {
        if v == c {
            return true
        }
    }
    return false
}

// UpdateFromGameState merges visible information from GameState into the AgentState.
// It preserves previously discovered map tiles and flower knowledge for tiles
// not visible in the current turn.
func (as *AgentState) UpdateFromGameState(gs *GameState, player int) {
    if as == nil {
        return
    }

    as.PlayerID = player
    as.Turn = gs.Turn

    // Clear transient per-turn lists
    as.MyBees = as.MyBees[:0]
    as.EnemyBees = as.EnemyBees[:0]

    // Iterate visible hexes and merge discoveries
    for coords, hex := range gs.Hexes {
        // Save the visible hex and terrain (overwrite with freshest data)
        as.Hexes[coords] = hex
        as.Map[coords] = hex.Terrain

        // Flowers: update current resource count if visible
        if hex.Terrain == FIELD {
            if hex.Resources > 0 {
                as.Flowers[coords] = hex.Resources
            } else {
                // resource zero means no flower currently
                delete(as.Flowers, coords)
            }
        }

        // Rocks: remember if we discover a rock
        if hex.Terrain == ROCK {
            if !containsCoords(as.Rocks, coords) {
                as.Rocks = append(as.Rocks, coords)
            }
        }

        // Entities: update recorded walls, hives and bees
        if hex.Entity != nil {
            switch hex.Entity.Type {
            case HIVE:
                if !containsCoords(as.Hives[hex.Entity.Player], coords) {
                    as.Hives[hex.Entity.Player] = append(as.Hives[hex.Entity.Player], coords)
                }
				if hex.Entity.Player == player {
                	as.Hives[hex.Entity.Player] = append(as.Hives[hex.Entity.Player], coords)
				} else {
					as.EnemyHives[hex.Entity.Player] = append(as.EnemyHives[hex.Entity.Player], coords)
				}
            case WALL:
                if !containsCoords(as.Walls, coords) {
                    as.Walls = append(as.Walls, coords)
                }
            case BEE:
                ui := UnitInfo{Coords: coords, Player: hex.Entity.Player, Type: BEE, HasFlower: hex.Entity.HasFlower}
                if hex.Entity.Player == player {
                    as.MyBees = append(as.MyBees, ui)
                } else {
                    as.EnemyBees = append(as.EnemyBees, ui)
                }
            }
        }
    }

    // Persistent identity tracking: match visible bees to tracked bees so
    // roles persist across moves. We'll match by nearest Last coords within
    // a small threshold; unmatched bees become new tracked bees and receive
    // a role chosen to balance role counts.
    roleList := []BeeRole{RoleHarvester, RoleScout, RoleDefender}
    as.BeeRoles = make(map[Coords]BeeRole)

    // Helper: count current tracked roles
    roleCounts := func() map[BeeRole]int {
        rc := make(map[BeeRole]int)
        for _, tb := range as.TrackedBees {
            rc[tb.Role]++
        }
        return rc
    }

    matchedTracked := make(map[string]bool)
    // For deterministic behavior, iterate visible bees in their existing order
    for _, u := range as.MyBees {
        bestID := ""
        bestDist := 1<<30
        for id, tb := range as.TrackedBees {
            if matchedTracked[id] {
                continue
            }
            d := tb.Last.Distance(u.Coords)
            if d < bestDist {
                bestDist = d
                bestID = id
            }
        }

        // Match threshold: accept matches only if reasonably close (<=2)
        if bestID != "" && bestDist <= 2 {
            tb := as.TrackedBees[bestID]
            tb.Last = u.Coords
            tb.LastSeenTurn = as.Turn
            as.BeeRoles[u.Coords] = tb.Role
            matchedTracked[bestID] = true
            continue
        }

        // No match -> create new tracked bee and choose a role with minimal count
        counts := roleCounts()
        chosen := roleList[0]
        minc := counts[chosen]
        for _, r := range roleList {
            if counts[r] < minc {
                chosen = r
                minc = counts[r]
            }
        }
        newID := fmt.Sprintf("tb-%d-%d", as.NextTrackedID, as.Turn)
        as.NextTrackedID++
        tb := &TrackedBee{ID: newID, Last: u.Coords, Role: chosen, LastSeenTurn: as.Turn}
        as.TrackedBees[newID] = tb
        matchedTracked[newID] = true
        as.BeeRoles[u.Coords] = chosen
    }

    // Cleanup stale tracked bees not seen for a long time
    staleThreshold := uint(20)
    for id, tb := range as.TrackedBees {
        if as.Turn > tb.LastSeenTurn && as.Turn-tb.LastSeenTurn > staleThreshold {
            delete(as.TrackedBees, id)
        }
    }
}

// GetBeeRole returns the role for a bee at coords if known, otherwise a default.
func (as *AgentState) GetBeeRole(c Coords) BeeRole {
    if as == nil {
        return RoleHarvester
    }
    if r, ok := as.BeeRoles[c]; ok {
        return r
    }
    return RoleHarvester
}

// IsFlower returns true when the coordinates contain a flower (field with resources).
func (as *AgentState) IsFlower(c Coords) bool {
    _, ok := as.Flowers[c]
    return ok
}

// GetNearestFlower returns the coord and whether it found one.
func (as *AgentState) GetNearestFlower(from Coords) (Coords, bool) {
    var best Coords
    bestDist := -1
    found := false
    for c := range as.Flowers {
        d := from.Distance(c)
        if !found || d < bestDist {
            bestDist = d
            best = c
            found = true
        }
    }
    return best, found
}

// BestDirectionTowards tries all neighbors and picks a direction that brings the
// hex closer to the target. Returns (direction, true) if a decrease is found.
func (as *AgentState) BestDirectionTowards(from Coords, to Coords) (Direction, bool) {
    best := NW
    bestDist := from.Distance(to)
    found := false
    for dir := range DirectionToOffset {
        n := from.Neighbour(dir)
        // Only consider known hexes
        if _, ok := as.Map[n]; !ok {
            continue
        }
        d := n.Distance(to)
        if d < bestDist {
            bestDist = d
            best = dir
            found = true
        }
    }
    return best, found
}

// String implements a simple debug formatter for the AgentState.
func (as *AgentState) String() string {
    return fmt.Sprintf("AgentState(player=%d, turn=%d, flowers=%d, rocks=%d, myBees=%d, enemyBees=%d)",
        as.PlayerID, as.Turn, len(as.Flowers), len(as.Rocks), len(as.MyBees), len(as.EnemyBees))
}

// DetailedString returns a multiline representation of the agent state,
// including hive locations, flowers with resource counts, rocks, walls and bees.
func (as *AgentState) DetailedString() string {
    var b strings.Builder

    b.WriteString(fmt.Sprintf("AgentState (player=%d, turn=%d)\n", as.PlayerID, as.Turn))

    // Hives
    b.WriteString("Hives:\n")
    if len(as.Hives) == 0 {
        b.WriteString("  (none)\n")
    } else {
        for player, coords := range as.Hives {
            b.WriteString(fmt.Sprintf("  Player %d:", player))
            for _, c := range coords {
                b.WriteString(fmt.Sprintf(" (%d,%d)", c.Row, c.Col))
            }
            b.WriteString("\n")
        }
    }

    // Flowers
    b.WriteString("Flowers (coords: resources):\n")
    if len(as.Flowers) == 0 {
        b.WriteString("  (none)\n")
    } else {
        // iterate deterministically by collecting keys
        for c, r := range as.Flowers {
            b.WriteString(fmt.Sprintf("  (%d,%d): %d\n", c.Row, c.Col, r))
        }
    }

    // Rocks
    b.WriteString("Rocks:\n")
    if len(as.Rocks) == 0 {
        b.WriteString("  (none)\n")
    } else {
        for _, c := range as.Rocks {
            b.WriteString(fmt.Sprintf("  (%d,%d)\n", c.Row, c.Col))
        }
    }

    // Walls
    b.WriteString("Walls:\n")
    if len(as.Walls) == 0 {
        b.WriteString("  (none)\n")
    } else {
        for _, c := range as.Walls {
            b.WriteString(fmt.Sprintf("  (%d,%d)\n", c.Row, c.Col))
        }
    }

    // Bees
    b.WriteString("My Bees:\n")
    if len(as.MyBees) == 0 {
        b.WriteString("  (none)\n")
    } else {
        for _, u := range as.MyBees {
            b.WriteString(fmt.Sprintf("  (%d,%d) hasFlower=%v\n", u.Coords.Row, u.Coords.Col, u.HasFlower))
        }
    }

    b.WriteString("Enemy Bees:\n")
    if len(as.EnemyBees) == 0 {
        b.WriteString("  (none)\n")
    } else {
        for _, u := range as.EnemyBees {
            b.WriteString(fmt.Sprintf("  player=%d (%d,%d) hasFlower=%v\n", u.Player, u.Coords.Row, u.Coords.Col, u.HasFlower))
        }
    }

    return b.String()
}

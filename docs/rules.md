# Game rules

The game is a simple strategy game, similar to Warcraft, Starcraft or Command and Conquer. Players build buildings, spawn units, gather ressources and compete to achieve a particular goal, such as conquest, domination, etc.

The theme is hives, bees and flowers, obviously :)

The game is played in simultaneous turns: players get information about their environment, then, all players submit commands at the same time, which are processed together to update the game state for the next turn.

## Map

The game is played on a hexagonal tiling of cells. Pre-written map files indicate:

- static terrain
- starting positions for players' buildings and units

### Static terrain

Terrain can be of three types:

- stone (unpassable and cannot be built in)
- empty
- flower fields, from which resources (flowers) can be foraged

The terrain is static and cannot change throughout the duration of the game.

### Dynamic entities

Players start the game with, and can create entities of three types:

- wax wall, a building that does not move, and simply blocks movement
- hive, a building that does not move, and can create more bees
- bee, a mobile unit which can perform most actions in the game

There can only ever be one entity per cell, which therefore prevents movement or additional building into that cell.

All entities have a certain number of hit points, which represent the amount of damage they can take before they are destroyed.

## Game state

In addition to the position and hit points of entities, the game state consists in:

- the number of remaining flowers in each flower field of the map
- the number of flowers in reserves for each player

## Gameplay

### Start

At the start of the game, players' starting units and buildings are placed in the possible spawning points as determined by the map.

### Field of view

Before each turn, all player agents receive from the server a partial view of the map: all terrain and entities that are within a fixed distance from their own hives and bees.

### Commands

Then, players' agents are expected to *simultaneously* submit commands for all their units and buildings. The order of commands is significant.

Commands are applied in rounds, as follows: in round N, the Nth commands of all player (if any) are gathered, shuffled and executed in a random order.

In order words, each players' commands will be executed in the order they are submitted, but interleaved randomly with the other players' for fairness. This gives players an incentive to place their most critical commands towards the beginning of their list.

Each unit or building can only perform a single action in a turn: subsequent attempts fail.

The possible commands for bees are the following:

- `move`: move one step in a given direction.
- `forage`: gather one flower from the field the bee is currently in. The field's flowers are reduced by one, and the player's resources immediately increase by one. If the bee is not in a field, or that field is empty, the command fails.
- `build wall`: create a wax wall.
- `build hive`: replace the bee with a hive in its current cell.
- `attack`: attack the entity in the adjacent cell in the given direction. The target entity's hit point are reduced by one. If they are brought down to zero, that entity is destroyed. If the target cell is empty, nothing happens.

The possible commands for hives are:

- `spawn bee`: create a new bee.

The commands `move`, `build wall`, and `spawn bee` all take a direction as parameter: they target the adjacent cell in the given direction. If that cell is blocked (the terrain is stone, or it contains an entity already), the command fails.

The commands `build wall`, `build hive` and `spawn bee` all have a cost in resources: the player's resources are immediately reduced by that cost. If the player does not have enough resources to pay that cost, the command fails.

### Influence

At the end of each turn, each player's influence is updated. All cells within the field of view of a hive are under its influence. If a cell is in the field of view of multiple players, it belongs to the one with the closest hive, if any.

### Victory conditions

At the end of the turn, the game state is checked for victory conditions. A player wins if:

- they are the only player with units or buildings remaining.
- OR: they influence more than 50% of all the cells in the map.

If several players reach victory conditions on the same turn, the one with most influence wins. Otherwise, the game is a shared victory between these players.

The game ends in a draw if there has been no change in influence counts in the last N turns.

## Hardcoded values

|          | Cost | Starting HP |
|----------|------|-------------|
| Bee      | 12   | 2           |
| Hive     | 24   | 12          |
| Wax wall | 6    | 6           |

Flower field initial content: 120 flowers.

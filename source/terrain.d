import std.algorithm;
import std.array;
import std.conv;
import std.typecons;

enum Terrain
{
	INVALID,
	EMPTY,
	ROCK,
	FIELD
}

struct Spawn
{
	enum Kind {HIVE, BEE};

	Kind kind;
	ubyte player;
	Coords coords;
}

// Doubled coordinates system (https://www.redblobgames.com/grids/hexagons/)
// Pointy tops (horizontal rows)
// Top-left corner is 0,0
// Rows increase by 1, (vertical) columns increase by 2

enum Direction
{
	E, SE, SW, W, NW, NE
}

const Coords[Direction] directionToOffset = [
	Direction.E: Coords(+0, +2),
	Direction.NE: Coords(-1, +1),
	Direction.NW: Coords(-1, -1),
	Direction.W: Coords(+0, -2),
	Direction.SW: Coords(+1, -1),
	Direction.SE: Coords(+1, +1)
];

struct Coords
{
	int row, col;

	invariant
	{
		assert(valid(row, col));
	}

	static bool valid(int row, int col)
	{
		return (row + col) % 2 == 0;
	}

	Coords opBinary(string op)(Coords rhs)
	{
		static if (op == "+") return Coords(row + rhs.row, col + rhs.col);
		else static if (op == "-") return Coords(row - rhs.row, col - rhs.col);
	}

	int opCmp(Coords rhs)
	{
		auto rowCmp = row - rhs.row;
		return rowCmp == 0 ? col - rhs.col : rowCmp;
	}

	Coords neighbour(Direction dir)
	{
		return this + directionToOffset[dir];
	}

	Coords[] neighbours()
	{
		return directionToOffset.values.map!(offset => this + offset).array;
	}
}

private const charToTerrain = [
	'.': Terrain.EMPTY,
	'F': Terrain.FIELD,
	'R': Terrain.ROCK
];

private const charToSpawn = [
	'H': Spawn.Kind.HIVE,
	'B': Spawn.Kind.BEE
];

char terrainToChar(Terrain kind)
{
	foreach(k, v; charToTerrain)
	if (v == kind)
		return k;

	return ' ';
}

alias Terrain[Coords] Map;

Tuple!(Map, Spawn[]) loadMap(string path)
{
	import std.stdio;

	Map map;
	Spawn[] spawns;

	foreach(int trow, string line; File(path, "r").lines)
	foreach(tcol, char c; line)
	{
		auto coords = Coords(trow, tcol.to!int / 2);

		if (c in charToTerrain)
		{
			map[coords] = charToTerrain[c];
		}
		else if (c in charToSpawn)
		{
			auto player = line[tcol + 1].to!string.to!ubyte;

			spawns ~= Spawn(charToSpawn[c], player, coords);
			map[coords] = Terrain.EMPTY;
		}
	}

	return tuple(map, spawns);
}

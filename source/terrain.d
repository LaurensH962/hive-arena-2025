import std.algorithm;
import std.array;
import std.conv;
import std.math;

enum Terrain
{
	INVALID,
	EMPTY,
	ROCK,
	FIELD
}

bool isWalkable(Terrain t)
{
	return t == Terrain.EMPTY || t == Terrain.FIELD;
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

immutable Coords[Direction] directionToOffset = [
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

	this(int row, int col)
	{
		if (!valid(row, col))
			throw new Exception("Invalid coordinates");

		this.row = row;
		this.col = col;
	}

	static bool valid(int row, int col)
	{
		return (row + col) % 2 == 0;
	}

	Coords opBinary(string op)(Coords rhs) const
	{
		static if (op == "+") return Coords(row + rhs.row, col + rhs.col);
		else static if (op == "-") return Coords(row - rhs.row, col - rhs.col);
	}

	int opCmp(Coords rhs) const
	{
		auto rowCmp = row - rhs.row;
		return rowCmp == 0 ? col - rhs.col : rowCmp;
	}

	Coords neighbour(Direction dir) const
	{
		return this + directionToOffset[dir];
	}

	Coords[] neighbours() const
	{
		return directionToOffset.values.map!(offset => this + offset).array;
	}

	uint distance(const Coords b) const
	{
		auto dcol = abs(this.col - b.col);
		auto drow = abs(this.row - b.row);
		return drow + max(0, (dcol - drow) / 2);
	}

	string toString() const @safe
	{
		import std.format;
		return format("%d:%d", row, col);
	}

	static Coords fromString(string s)
	{
		auto parts = s.split(":");
		return Coords(parts[0].to!int, parts[1].to!int);
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
	foreach (k, v; charToTerrain)
	if (v == kind)
		return k;

	return ' ';
}

alias Map = Terrain[Coords];

struct MapData
{
	string name;
	Map map;
	Spawn[] spawns;
}

MapData loadMap(string path)
{
	import std.stdio;

	Map map;
	Spawn[] spawns;

	foreach (int trow, string line; File(path, "r").lines)
	foreach (tcol, char c; line)
	{
		if (!Coords.valid(trow, tcol.to!int / 2))
			continue;

		auto coords = Coords(trow, tcol.to!int / 2);

		if (auto terrain = c in charToTerrain)
		{
			map[coords] = *terrain;
		}
		else if (auto kind = c in charToSpawn)
		{
			auto player = line[tcol + 1].to!string.to!ubyte;

			spawns ~= Spawn(*kind, player, coords);
			map[coords] = Terrain.EMPTY;
		}
	}

	return MapData(path, map, spawns);
}

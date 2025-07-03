import std.algorithm;
import std.array;
import std.conv;
import std.typecons;

enum HexKind
{
	EMPTY,
	ROCK,
	FIELD,
	HIVE,
	BEE,
	WALL
}

struct Hex
{
	HexKind kind;
	ubyte player;
	ubyte hp;
}

// Doubled coordinates system (https://www.redblobgames.com/grids/hexagons/)
// Pointy tops (horizontal rows)
// Top-left corner is 0,0
// Rows increase by 1, (vertical) columns increase by 2

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

	static const Coords[] neighbourOffsets = [
		Coords(+0, +2), Coords(-1, +1),
		Coords(-1, -1), Coords(+0, -2),
		Coords(+1, -1), Coords(+1, +1)
	];

	Coords[] neighbours()
	{
		return neighbourOffsets.map!(offset => this + offset).array;
	}
}

private const charToKind = [
	'.': HexKind.EMPTY,
	'H': HexKind.HIVE,
	'B': HexKind.BEE,
	'F': HexKind.FIELD,
	'R': HexKind.ROCK,
	'W': HexKind.WALL
];

char kindToChar(HexKind kind)
{
	foreach(k, v; charToKind)
	if (v == kind)
		return k;

	return ' ';
}

Hex[Coords] loadMap(string path)
{
	import std.stdio;

	Hex[Coords] map;

	foreach(int trow, string line; File(path, "r").lines)
	foreach(tcol, char c; line)
	{
		Hex hex;
		if (c in charToKind)
		{
			hex.kind = charToKind[c];
			if (hex.kind == HexKind.HIVE || hex.kind == HexKind.BEE)
			{
				hex.player = line[tcol + 1].to!string.to!ubyte;
			}
			map[Coords(trow, tcol.to!int / 2)] = hex;
		}
	}

	return map;
}

Tuple!(Coords, Hex)[] sortByCoords(Hex[Coords] m)
{
	return m.byPair.array
		.sort!((a,b) => a.key < b.key)
		.map!(a => tuple(a.key, a.value))
		.array;
}

string mapToString(Hex[Coords] m)
{
	import std.format;

	auto res = "";

	auto top = m.keys.map!"a.row".minElement;
	auto bottom = m.keys.map!"a.row".maxElement;
	auto left = m.keys.map!"a.col".minElement;
	auto right = m.keys.map!"a.col".maxElement;

	foreach (row; top .. bottom + 1)
	{
		if (row % 2 == 1) res ~= "  ";
		foreach (col; left .. right + 1)
		{
			if (!Coords.valid(row, col)) continue;

			auto coords = Coords(row, col);
			char c1 = ' ';
			char c2 = ' ';
			if (coords in m)
			{
				auto hex = m[coords];
				c1 = hex.kind.kindToChar;
				c2 = hex.player != 0 ? hex.player.to!string[0] : ' ';
			}
			res ~= format("%c%c  ", c1, c2);
		}
		res ~= '\n';
	}

	return res;
}

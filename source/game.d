import std.algorithm;
import std.array;
import std.conv;

import terrain;
import order;
import utils;

// const ubyte[Terrain] maxHP = [
// 	Terrain.HIVE: 12,
// 	Terrain.BEE: 2,
// 	Terrain.FIELD: 120,
// 	Terrain.WALL: 6,
// 	Terrain.EMPTY: 0,
// 	Terrain.ROCK: 0
// ];

const INIT_FIELD_FLOWERS = 120;
const INIT_HIVE_HP = 12;
const INIT_BEE_HP = 2;

class Unit
{
	Coords position;
	ubyte player;
	uint hp;

	this(Coords position, ubyte player, uint hp)
	{
		this.position = position;
		this.player = player;
		this.hp = hp;
	}
}

class GameState
{
	ubyte numPlayers;
	const Map hexes;

	uint[] playerFlowers;
	uint[Coords] fieldFlowers;
	Unit[] hives;
	Unit[] bees;

	private static const ubyte[][] playerMappings = [
		[],
		[0, 1, 0, 0, 0, 0, 0],
		[0, 1, 0, 0, 2, 0, 0],
		[0, 1, 0, 2, 0, 3, 0],
		[0, 0, 1, 2, 0, 3, 4],
		[0, 1, 2, 3, 4, 5, 0],
		[0, 1, 2, 3, 4, 5, 6]
	];

	this(const Map hexes, const Spawn[] spawns, ubyte numPlayers)
	{
		assert(numPlayers >= 1 && numPlayers <= 6);

		this.numPlayers = numPlayers;
		this.hexes = hexes;

		// Create units for existing players

		foreach(spawn; spawns)
		{
			auto player = playerMappings[numPlayers][spawn.player];
			if (player == 0)
				continue;

			final switch (spawn.kind)
			{
				case Spawn.Kind.HIVE:
					hives ~= new Unit(spawn.coords, player, INIT_HIVE_HP);
					break;

				case Spawn.Kind.BEE:
					bees ~= new Unit(spawn.coords, player, INIT_BEE_HP);
					break;
			}
		}

		// Prepare flower fields

		foreach(coords, terrain; hexes)
		{
			if (terrain == Terrain.FIELD)
				fieldFlowers[coords] = INIT_FIELD_FLOWERS;
		}

		this.playerFlowers = new uint[numPlayers + 1];
	}

	Unit find(string which)(Coords coords)
	{
		Unit[] arr;

		static if (which == "bee") arr = bees;
		else static if (which == "hive") arr = hives;
		else static assert(0);

		auto res = arr.find!(unit => unit.position == coords);
		return res.empty ? null : res.front;
	}

	// void applyOrders(Order[] orders)
	// {
	// 	foreach(order; orders)
	// 		order.validate(this);
	//
	// 	foreach(order; orders)
	// 	{
	// 		// Don't apply invalid orders
	//
	// 		if (order.status != Order.Status.PENDING)
	// 			continue;
	//
	// 		// The unit might have been destroyed
	//
	// 		if (hexes[order.coords].hp <= 0)
	// 		{
	// 			order.status = Order.Status.DESTROYED;
	// 			continue;
	// 		}
	//
	// 		// Otherwise, go!
	//
	// 		order.apply(this);
	// 	}
	// }

	override string toString()
	{
		import std.format;

		auto res = "";

		auto top = hexes.keys.map!"a.row".minElement;
		auto bottom = hexes.keys.map!"a.row".maxElement;
		auto left = hexes.keys.map!"a.col".minElement;
		auto right = hexes.keys.map!"a.col".maxElement;

		foreach (row; top .. bottom + 1)
		{
			if (row % 2 == 1) res ~= "  ";
			foreach (col; left .. right + 1)
			{
				if (!Coords.valid(row, col)) continue;

				auto coords = Coords(row, col);
				char c1 = ' ';
				char c2 = ' ';
				if (coords in hexes)
				{
					c1 = terrain.terrainToChar(hexes[coords]);

					if (auto bee = find!"bee"(coords))
					{
						c1 = 'B';
						c2 = bee.player.to!string[0];
					}
					else if (auto hive = find!"hive"(coords))
					{
						c1 = 'H';
						c2 = hive.player.to!string[0];
					}
				}
				res ~= format("%c%c  ", c1, c2);
			}
			res ~= '\n';
		}

		return res;
	}
}

import std.algorithm;
import std.array;
import std.conv;
import std.random;

import terrain;
import order;

const INIT_FIELD_FLOWERS = 120;
const INIT_HIVE_HP = 12;
const INIT_BEE_HP = 2;
const INIT_WALL_HP = 6;

const BEE_COST = 12;
const HIVE_COST = 24;
const WALL_COST = 6;

class Entity
{
	enum Type
	{
		WALL,
		HIVE,
		BEE
	}

	Type type;
	int hp;
	ubyte player;

	this(Type type, int hp, ubyte player)
	{
		this.type = type;
		this.hp = hp;
		this.player = player;
	}
}

class GameState
{
	const ubyte numPlayers;
	const Map staticMap;

	uint[] playerFlowers;
	uint[Coords] fieldFlowers;
	Entity[Coords] entities;

	private static const ubyte[][] playerMappings = [
		[],
		[ 0, -1, -1, -1, -1, -1],
		[ 0, -1, -1,  1, -1, -1],
		[ 0, -1,  1, -1,  2, -1],
		[-1,  0,  1, -1,  2,  3],
		[ 0,  1,  2,  3,  4, -1],
		[ 0,  1,  2,  3,  4,  5]
	];

	this(const Map staticMap, const Spawn[] spawns, ubyte numPlayers)
	{
		assert(numPlayers >= 1 && numPlayers <= 6);

		this.numPlayers = numPlayers;
		this.staticMap = staticMap;

		// Create units for existing players

		foreach (spawn; spawns)
		{
			auto player = playerMappings[numPlayers][spawn.player];
			if (player == -1)
				continue;

			final switch (spawn.kind)
			{
				case Spawn.Kind.HIVE:
					entities[spawn.coords] = new Entity(Entity.Type.HIVE, INIT_HIVE_HP, player);
					break;

				case Spawn.Kind.BEE:
					entities[spawn.coords] = new Entity(Entity.Type.BEE, INIT_BEE_HP, player);
					break;
			}
		}

		// Prepare flower fields

		foreach (coords, terrain; staticMap)
		{
			if (terrain == Terrain.FIELD)
				fieldFlowers[coords] = INIT_FIELD_FLOWERS;
		}

		// And player resources

		this.playerFlowers = new uint[numPlayers];
	}

	Entity getEntityAt(Coords coords)
	{
		return entities.get(coords, null);
	}

	Terrain getTerrainAt(Coords coords)
	{
		return staticMap.get(coords, Terrain.INVALID);
	}

	void processOrders(Order[][] orders)
	{
		// Randomize rounds between players

		auto numRounds = orders.map!(arr => arr.length).maxElement;
		Order[][] rounds;

		foreach (round; 0 .. numRounds)
		{
			Order[] roundOrders;
			foreach (playerOrders; orders)
			{
				if (round < playerOrders.length)
					roundOrders ~= playerOrders[round];
			}

			rounds ~= roundOrders.randomShuffle;
		}

		// Then apply them in order, checking that units are not ordered more than once

		bool[Entity] acted;

		foreach (round; rounds)
		foreach (order; round)
		{
			auto unit = getEntityAt(order.coords);
			if (unit in acted)
			{
				order.status = Order.Status.UNIT_ALREADY_ACTED;
				continue;
			}

			order.apply();
			acted[unit] = true;
		}
	}

	override string toString()
	{
		import std.format;

		auto res = "";

		auto top = staticMap.keys.map!"a.row".minElement;
		auto bottom = staticMap.keys.map!"a.row".maxElement;
		auto left = staticMap.keys.map!"a.col".minElement;
		auto right = staticMap.keys.map!"a.col".maxElement;

		foreach (row; top .. bottom + 1)
		{
			if (row % 2 == 1) res ~= "  ";
			foreach (col; left .. right + 1)
			{
				if (!Coords.valid(row, col)) continue;

				auto coords = Coords(row, col);
				char c1 = ' ';
				char c2 = ' ';
				if (coords in staticMap)
				{
					c1 = terrain.terrainToChar(staticMap[coords]);

					if (auto entity = getEntityAt(coords))
					{
						final switch (entity.type)
						{
							case Entity.Type.BEE:
								c1 = 'B';
								c2 = entity.player.to!string[0];
								break;
							case Entity.Type.HIVE:
								c1 = 'H';
								c2 = entity.player.to!string[0];
								break;
							case Entity.Type.WALL:
								c1 = 'W';
								break;
						}
					}
				}
				res ~= format("%c%c  ", c1, c2);
			}
			res ~= '\n';
		}

		res ~= "Resources: " ~ playerFlowers.to!string;

		return res;
	}
}

import std.algorithm;
import std.array;
import std.conv;
import std.random;
import std.typecons;
import std.range;

import terrain;
import order;

const INIT_FIELD_FLOWERS = 60;
const INIT_HIVE_HP = 12;
const INIT_BEE_HP = 2;
const INIT_WALL_HP = 6;

const BEE_COST = 12;
const HIVE_COST = 24;
const WALL_COST = 6;

const HIVE_FIELD_OF_VIEW = 4;
const INFLUENCE_TIMEOUT = 50;

alias PlayerID = uint;

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
	PlayerID player;

	this(Type type, int hp, PlayerID player)
	{
		this.type = type;
		this.hp = hp;
		this.player = player;
	}
}

class GameState
{
	const PlayerID numPlayers;
	const Map staticMap;

	uint turn;

	uint[] playerResources;
	uint[Coords] mapResources;
	Entity[Coords] entities;

	PlayerID[Coords] influence;
	uint lastInfluenceChange;

	PlayerID[] winners;
	bool gameOver;

	private static const byte[][] playerMappings = [
		[],
		[ 0, -1, -1, -1, -1, -1],
		[ 0, -1, -1,  1, -1, -1],
		[ 0, -1,  1, -1,  2, -1],
		[-1,  0,  1, -1,  2,  3],
		[ 0,  1,  2,  3,  4, -1],
		[ 0,  1,  2,  3,  4,  5]
	];

	static bool validNumPlayers(PlayerID numPlayers)
	{
		return numPlayers >= 1 && numPlayers <= 6;
	}

	this(const MapData mapData, PlayerID numPlayers)
	{
		this(mapData.map, mapData.spawns, numPlayers);
	}

	this(const Map map, const Spawn[] spawns, PlayerID numPlayers)
	{
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
				mapResources[coords] = INIT_FIELD_FLOWERS;
		}

		// And player resources

		this.playerResources = new uint[numPlayers];

		// Compute starting influence and the unlikely endgame

		updateInfluence();
		checkEndGame();
	}

	Entity getEntityAt(Coords coords)
	{
		return entities.get(coords, null);
	}

	Terrain getTerrainAt(Coords coords)
	{
		return staticMap.get(coords, Terrain.INVALID);
	}

	Order[] processOrders(Order[][] orders)
	{
		if (gameOver)
			throw new Exception("Cannot process orders in a finished game");

		// Separate orders by round

		auto rounds = orders.transposed;

		// Then apply them in random order within each round, checking that units are not ordered more than once

		bool[Entity] acted;
		Order[] processed;

		foreach (round; rounds)
		{
			foreach (order; round.array.randomShuffle)
			{
				auto unit = getEntityAt(order.coords);
				if (unit in acted)
				{
					order.status = Order.Status.UNIT_ALREADY_ACTED;
					continue;
				}

				order.apply();
				acted[unit] = true;
				processed ~= order;
			}
		}

		turn++;
		updateInfluence();
		checkEndGame();

		return processed;
	}

	void updateInfluence()
	{
		auto previousInfluence = influence.dup;
		influence.clear();

		auto hives = entities.byKeyValue
			.filter!(pair => pair.value.type == Entity.Type.HIVE).array;

		if (hives.length == 0)
			return;

		foreach(cell; staticMap.keys)
		{
			auto minDist = uint.max;
			bool[PlayerID] closestPlayers;

			foreach (hive; hives)
			{
				auto dist = cell.distance(hive.key);
				if (dist > HIVE_FIELD_OF_VIEW)
					continue;

				if (dist < minDist)
				{
					minDist = dist;
					closestPlayers.clear();
				}

				if (dist <= minDist)
				{
					closestPlayers[hive.value.player] = true;
				}
			}

			if (closestPlayers.length == 1)
				influence[cell] = closestPlayers.keys[0];
		}

		if (influence != previousInfluence)
			lastInfluenceChange = turn;
	}

	void checkEndGame()
	{
		// No influence change in a while

		if (turn - lastInfluenceChange > INFLUENCE_TIMEOUT)
		{
			gameOver = true;
			return;
		}

		// Count influenced cells and hives

		auto influenceCounts = new uint[numPlayers];
		auto hiveCounts = new uint[numPlayers];

		foreach (cell, player; influence)
			influenceCounts[player]++;

		foreach (cell, entity; entities)
		if (entity.type == Entity.Type.HIVE)
			hiveCounts[entity.player]++;

		// If a single player has hives, they win

		if (hiveCounts.count!(a => a > 0) == 1)
		{
			winners ~= cast(PlayerID) hiveCounts.maxIndex;
			gameOver = true;
			return;
		}

		// Check if anyone has more than half the map influenced

		auto maxInfluence = influenceCounts.maxElement;
		if (maxInfluence <= staticMap.length / 2)
			return;

		foreach (PlayerID p; 0 .. numPlayers)
		if (influenceCounts[p] == maxInfluence)
			winners ~= p;

		gameOver = true;
	}
}

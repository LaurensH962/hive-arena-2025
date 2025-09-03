import std.algorithm;
import std.random;
import std.range;
import std.typecons;

import vibe.data.serialization;

import terrain;

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
	@byName enum Type
	{
		WALL,
		HIVE,
		BEE
	}

	Type type;
	int hp;
	PlayerID player;

	this() @safe {}

	this(Type type, int hp, PlayerID player)
	{
		this.type = type;
		this.hp = hp;
		this.player = player;
	}
}

class Hex
{
	@byName Terrain terrain;

	Nullable!uint resources;
	Nullable!PlayerID influence;
	@optional Entity entity;
	
	this() @safe {} 
	
	this(Terrain terrain)
	{
		this.terrain = terrain;
	}
}

class Order
{
	@byName enum Type
	{
		MOVE,
		ATTACK,
		BUILD_WALL,
		BUILD_HIVE,
		FORAGE,
		SPAWN
	}

	@byName enum Status
	{
		PENDING,
		INVALID_UNIT,
		BLOCKED,
		INVALID_TARGET,
		CANNOT_FORAGE,
		NOT_ENOUGH_RESOURCES,
		UNIT_ALREADY_ACTED,
		OK
	}

	Type type;
	PlayerID player;
	Coords coords;
	@optional Direction direction;

	@optional Status status;
	
	Entity.Type unitType()
	{
		if (type == Type.SPAWN)
			return Entity.Type.HIVE;
		else
			return Entity.Type.BEE;
	}
	
	Coords target() const
	{
		return coords.neighbour(direction);
	}
}

class GameState
{
	PlayerID numPlayers;

	uint turn;
	
	Hex[Coords] hexes;
	uint[] playerResources;
	uint lastInfluenceChange;

	PlayerID[] winners = [-1];
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

	this() @safe {}

	this(MapData mapData, PlayerID numPlayers)
	{
		this(mapData.map, mapData.spawns, numPlayers);
	}

	this(const Terrain[Coords] map, const Spawn[] spawns, PlayerID numPlayers)
	{
		this.numPlayers = numPlayers;

		foreach (coords, terrain; map)
			hexes[coords] = new Hex(terrain);

		// Create units for existing players

		foreach (spawn; spawns)
		{
			auto player = playerMappings[numPlayers][spawn.player];
			if (player == -1)
				continue;

			final switch (spawn.kind)
			{
				case Spawn.Kind.HIVE:
					hexes[spawn.coords].entity = new Entity(Entity.Type.HIVE, INIT_HIVE_HP, player);
					break;

				case Spawn.Kind.BEE:
					hexes[spawn.coords].entity = new Entity(Entity.Type.BEE, INIT_BEE_HP, player);
					break;
			}
		}

		// Prepare flower fields

		foreach (coords, hex; hexes)
		{
			if (hex.terrain == Terrain.FIELD)
				hex.resources = INIT_FIELD_FLOWERS;
		}

		// And player resources

		this.playerResources = new uint[numPlayers];

		// Compute starting influence and the unlikely endgame

		updateInfluence();
		checkEndGame();
	}

	Entity entityAt(Coords coords)
	{
		auto hex = coords in hexes;
		return hex ? hex.entity : null;
	}

	Terrain terrainAt(Coords coords)
	{
		auto hex = coords in hexes;
		return hex ? hex.terrain : Terrain.INVALID;
	}

	auto entities() const
	{
		return hexes
			.byKeyValue
			.filter!(h => h.value.entity !is null)
			.map!(pair => tuple!("coords", "entity")(pair.key, pair.value.entity));
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
				auto unit = entityAt(order.coords);
				if (unit in acted)
				{
					order.status = Order.Status.UNIT_ALREADY_ACTED;
					continue;
				}

				applyOrder(order);
				acted[unit] = true;
				processed ~= order;
			}
		}

		turn++;
		updateInfluence();
		checkEndGame();

		return processed;
	}

	private void applyOrder(Order order)
	{
		final switch (order.type)
		{
			case Order.Type.MOVE: return applyMoveOrder(order);
			case Order.Type.ATTACK: return applyAttackOrder(order);
			case Order.Type.BUILD_WALL: return applyBuildWallOrder(order);
			case Order.Type.BUILD_HIVE: return applyBuildHiveOrder(order);
			case Order.Type.FORAGE: return applyForageOrder(order);
			case Order.Type.SPAWN: return applySpawnOrder(order);
		}
	}

	private Entity getUnit(Order order)
	{
		auto unit = entityAt(order.coords);
		if (!unit || unit.type != order.unitType || unit.player != order.player)
		{
			order.status = Order.Status.INVALID_UNIT;
			return null;
		}
		
		return unit;
	}
	
	private bool targetIsBlocked(Order order)
	{
		auto targetTerrain = terrainAt(order.target);
		auto entity = entityAt(order.target);

		if (!targetTerrain.isWalkable || entity !is null)
		{
			order.status = Order.Status.BLOCKED;
			return true;
		}

		return false;
	}
	
	private bool tryToPay(Order order, uint cost)
	{
		if (playerResources[order.player] < cost)
		{
			order.status = Order.Status.NOT_ENOUGH_RESOURCES;
			return false;
		}
		playerResources[order.player] -= cost;
		return true;
	}

	private void applyMoveOrder(Order order)
	{
		auto bee = getUnit(order);
		if (!bee) return;
		if (targetIsBlocked(order)) return;
		
		hexes[order.coords].entity = null;
		hexes[order.target].entity = bee;

		order.status = Order.Status.OK;
	}

	private void applyAttackOrder(Order order)
	{
		if (!getUnit(order)) return;

		auto entity = entityAt(order.target);
		if (entity is null)
		{
			order.status = Order.Status.INVALID_TARGET;
			return;
		}

		entity.hp--;
		if (entity.hp <= 0)
		{
			hexes[order.target].entity = null;
		}

		order.status = Order.Status.OK;
	}
	
	private void applyBuildWallOrder(Order order)
	{
		if (!getUnit(order)) return;
		if (targetIsBlocked(order)) return;
		if (!tryToPay(order, WALL_COST)) return;

		auto wall = new Entity(Entity.Type.WALL, hp: INIT_WALL_HP, player: order.player);
		hexes[order.target].entity = wall;

		order.status = Order.Status.OK;
	}
	
	private void applyBuildHiveOrder(Order order)
	{
		if (!getUnit(order)) return;
		if (!tryToPay(order, HIVE_COST)) return;

		auto hive = new Entity(Entity.Type.HIVE, hp: INIT_HIVE_HP, player: order.player);
		hexes[order.coords].entity = hive;

		order.status = Order.Status.OK;
	}
	
	private void applyForageOrder(Order order)
	{
		if (!getUnit(order)) return;
		
		auto hex = hexes[order.coords];
		if (hex.terrain != Terrain.FIELD || hex.resources == 0)
		{
			order.status = Order.Status.CANNOT_FORAGE;
			return;
		}

		hex.resources = hex.resources.get - 1;
		playerResources[order.player]++;

		order.status = Order.Status.OK;
	}
	
	private void applySpawnOrder(Order order)
	{
		if (!getUnit(order)) return;
		if (targetIsBlocked(order)) return;
		if (!tryToPay(order, BEE_COST)) return;

		auto bee = new Entity(Entity.Type.BEE, hp: INIT_BEE_HP, player: order.player);
		hexes[order.target].entity = bee;

		order.status = Order.Status.OK;
	}

	void updateInfluence()
	{
		auto hives = entities
			.filter!(pair => pair.entity.type == Entity.Type.HIVE).array;

		foreach (coords, hex; hexes)
		{
			auto minDist = uint.max;
			bool[PlayerID] closestPlayers;
			
			auto previousInfluence = hex.influence;

			foreach (hive; hives)
			{
				auto dist = coords.distance(hive.coords);
				if (dist > HIVE_FIELD_OF_VIEW)
					continue;

				if (dist < minDist)
				{
					minDist = dist;
					closestPlayers.clear();
				}

				if (dist <= minDist)
				{
					closestPlayers[hive.entity.player] = true;
				}
			}

			if (closestPlayers.length == 1)
				hex.influence = closestPlayers.keys[0];
			else
				hex.influence.nullify;
			
			if (hex.influence != previousInfluence)
				lastInfluenceChange = turn;
		}
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

		foreach (coords, hex; hexes)
		{
			if (!hex.influence.isNull)
				influenceCounts[hex.influence.get]++;
			
			if (hex.entity && hex.entity.type == Entity.Type.HIVE)
				hiveCounts[hex.entity.player]++;
		}

		// If a single player has hives, they win

		if (hiveCounts.count!(a => a > 0) == 1)
		{
			winners ~= cast(PlayerID) hiveCounts.maxIndex;
			gameOver = true;
			return;
		}

		// Check if anyone has more than half the map influenced

		auto maxInfluence = influenceCounts.maxElement;
		if (maxInfluence <= hexes.length / 2)
			return;

		foreach (PlayerID p; 0 .. numPlayers)
			if (influenceCounts[p] == maxInfluence)
				winners ~= p;

		gameOver = true;
	}
	
	private bool isVisibleBy(Coords coords, PlayerID player) const
	{
		return entities
			.filter!(e => e.entity.player == player)
			.any!(e => e.coords.distance(coords) <= HIVE_FIELD_OF_VIEW);
	}
	
	GameState playerView(PlayerID player)
	{
		auto view = new GameState();
		
		view.numPlayers = numPlayers;
	 	view.turn = turn;
		
		foreach (coords, hex; hexes)
			if (isVisibleBy(coords, player))
				view.hexes[coords] = hex;
		
		view.playerResources = [playerResources[player]];
		view.lastInfluenceChange = lastInfluenceChange;

		view.winners = winners;
		view.gameOver = gameOver;
		
		return view;
	}
}

import std.algorithm;

import game;
import terrain;

class Order
{
	enum Status
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

	GameState state;
	const PlayerID player;
	const Coords coords;

	Status status;

	this(GameState state, PlayerID player, Coords coords)
	{
		this.state = state;
		this.player = player;
		this.coords = coords;
	}

	Entity getUnit(Entity.Type type)
	{
		auto unit = state.entityAt(coords);
		if (unit is null || unit.type != type || unit.player != player)
		{
			status = Status.INVALID_UNIT;
			return null;
		}

		return unit;
	}

	bool tryToPay(uint cost)
	{
		if (state.playerResources[player] < cost)
		{
			status = Status.NOT_ENOUGH_RESOURCES;
			return false;
		}
		state.playerResources[player] -= cost;
		return true;
	}

	abstract void apply();
}

class TargetOrder : Order
{
	const Direction direction;

	this(GameState state, PlayerID player, Coords coords, Direction direction)
	{
		super(state, player, coords);
		this.direction = direction;
	}

	Coords target() const
	{
		return coords.neighbour(direction);
	}

	bool targetIsBlocked()
	{
		auto targetTerrain = state.terrainAt(target);
		auto entity = state.entityAt(target);

		if (!targetTerrain.isWalkable || entity !is null)
		{
			status = Status.BLOCKED;
			return true;
		}

		return false;
	}
}

class MoveOrder : TargetOrder
{
	this(GameState state, PlayerID player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		auto bee = getUnit(Entity.Type.BEE);
		if (bee is null) return;
		if (targetIsBlocked()) return;

		state.hexes[coords].entity = null;
		state.hexes[target].entity = bee;

		status = Status.OK;
	}
}

class AttackOrder : TargetOrder
{
	this(GameState state, PlayerID player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		if (getUnit(Entity.Type.BEE) is null) return;

		auto entity = state.entityAt(target);
		if (entity is null)
		{
			status = Status.INVALID_TARGET;
			return;
		}

		entity.hp--;
		if (entity.hp <= 0)
		{
			state.hexes[target].entity = null;
		}

		status = Status.OK;
	}
}

class BuildWallOrder : TargetOrder
{
	this(GameState state, PlayerID player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		if (getUnit(Entity.Type.BEE) is null) return;
		if (targetIsBlocked) return;

		if (!tryToPay(WALL_COST)) return;

		auto wall = new Entity(Entity.Type.WALL, hp: INIT_WALL_HP, player: player);
		state.hexes[target].entity = wall;

		status = Status.OK;
	}
}

class ForageOrder : Order
{
	this(GameState state, PlayerID player, Coords coords)
	{
		super(state, player, coords);
	}

	override void apply()
	{
		if (getUnit(Entity.Type.BEE) is null) return;

		auto terrain = state.terrainAt(coords);
		if (terrain != Terrain.FIELD || state.hexes[coords].resources == 0)
		{
			status = Status.CANNOT_FORAGE;
			return;
		}

		state.hexes[coords].resources = state.hexes[coords].resources.get - 1;
		state.playerResources[player]++;

		status = Status.OK;
	}
}

class BuildHiveOrder : Order
{
	this(GameState state, PlayerID player, Coords coords)
	{
		super(state, player, coords);
	}

	override void apply()
	{
		if (getUnit(Entity.Type.BEE) is null) return;

		if (!tryToPay(HIVE_COST)) return;

		auto hive = new Entity(Entity.Type.HIVE, hp: INIT_HIVE_HP, player: player);
		state.hexes[coords].entity = hive;

		status = status.OK;
	}
}

class SpawnOrder : TargetOrder
{
	this(GameState state, PlayerID player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		if (getUnit(Entity.Type.HIVE) is null) return;
		if (targetIsBlocked) return;

		if (!tryToPay(BEE_COST)) return;

		auto bee = new Entity(Entity.Type.BEE, hp: INIT_BEE_HP, player: player);
		state.hexes[target].entity = bee;

		status = status.OK;
	}
}

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
		OK
	}

	GameState state;
	const ubyte player;
	const Coords coords;

	Status status;

	this(GameState state, ubyte player, Coords coords)
	{
		this.state = state;
		this.player = player;
		this.coords = coords;
	}

	T getUnit(T : Unit)()
	{
		auto unit = cast(T) state.getEntityAt(coords);
		if (unit is null || unit.player != player)
		{
			status = Status.INVALID_UNIT;
			return null;
		}

		return unit;
	}

	bool tryToPay(uint cost)
	{
		if (state.playerFlowers[player] < cost)
		{
			status = Status.NOT_ENOUGH_RESOURCES;
			return false;
		}
		state.playerFlowers[player] -= cost;
		return true;
	}

	abstract void apply();
}

class TargetOrder : Order
{
	const Direction direction;

	this(GameState state, ubyte player, Coords coords, Direction direction)
	{
		super(state, player, coords);
		this.direction = direction;
	}

	Coords target() const pure
	{
		return coords.neighbour(direction);
	}

	bool targetIsBlocked()
	{
		auto targetTerrain = state.getTerrainAt(target);
		auto entity = state.getEntityAt(target);

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
	this(GameState state, ubyte player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		auto bee = getUnit!Bee();
		if (bee is null) return;
		if (targetIsBlocked()) return;

		bee.position = target;

		state.entities.remove(coords);
		state.entities[target] = bee;

		status = Status.OK;
	}
}

class AttackOrder : TargetOrder
{
	this(GameState state, ubyte player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		if (getUnit!Bee is null) return;

		auto entity = state.getEntityAt(target);
		if (entity is null)
		{
			status = Status.INVALID_TARGET;
			return;
		}

		entity.hp--;
		if (entity.hp <= 0)
		{
			state.entities.remove(target);
		}

		status = Status.OK;
	}
}

class BuildWallOrder : TargetOrder
{
	this(GameState state, ubyte player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		if (getUnit!Bee is null) return;
		if (targetIsBlocked) return;

		if (!tryToPay(WALL_COST)) return;

		auto wall = new Wall(target);
		state.entities[target] = wall;

		status = Status.OK;
	}
}

class ForageOrder : Order
{
	this(GameState state, ubyte player, Coords coords)
	{
		super(state, player, coords);
	}

	override void apply()
	{
		if (getUnit!Bee is null) return;

		auto terrain = state.getTerrainAt(coords);
		if (terrain != Terrain.FIELD || state.fieldFlowers[coords] == 0)
		{
			status = Status.CANNOT_FORAGE;
			return;
		}

		state.fieldFlowers[coords]--;
		state.playerFlowers[player]++;

		status = Status.OK;
	}
}

class BuildHiveOrder : Order
{
	this(GameState state, ubyte player, Coords coords)
	{
		super(state, player, coords);
	}

	override void apply()
	{
		if (getUnit!Bee is null) return;

		if (!tryToPay(HIVE_COST)) return;

		auto hive = new Hive(coords, player);
		state.entities[coords] = hive;
	}
}

class SpawnOrder : TargetOrder
{
	this(GameState state, ubyte player, Coords coords, Direction direction)
	{
		super(state, player, coords, direction);
	}

	override void apply()
	{
		if (getUnit!Hive is null) return;
		if (targetIsBlocked) return;

		if (!tryToPay(BEE_COST)) return;

		auto bee = new Bee(target, player);
		state.entities[target] = bee;
	}
}

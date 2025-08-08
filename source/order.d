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

		auto targetTerrain = state.getTerrainAt(target);
		auto entity = state.getEntityAt(target);

		if (targetTerrain != Terrain.EMPTY || entity !is null)
		{
			status = Status.BLOCKED;
			return;
		}

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
		auto bee = getUnit!Bee();
		if (bee is null) return;

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
//
// class ForageOrder : TargetOrder
// {
//
// }
//
// class BuildWallOrder : TargetOrder
// {
//
// }
//
// class HiveOrder : Order
// {
//
// }

// class SpawnOrder : Order
// {
// 	override void checkUnitType(GameState state)
// 	{
// 		if (!state.find!"hive"(coords))
// 			status = Status.INVALID_UNIT;
// 	}
// }

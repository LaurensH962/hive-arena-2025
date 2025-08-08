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
		DESTROYED,

		OK
	}

	Status status;
	ubyte player;
	Coords coords;

	abstract void apply(GameState state);
}

class TargetOrder : Order
{
	Direction direction;
}

class MoveOrder : TargetOrder
{
	override void apply(GameState state)
	{
		auto bee = cast(Bee) state.getEntityAt(coords);
		if (bee is null || bee.player != player)
		{
			status = Status.INVALID_UNIT;
			return;
		}

		auto target = coords.neighbour(direction);
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

// class AttackOrder : TargetOrder
// {
// 	override void apply(GameState state)
// 	{
// 		auto target = coords.neighbour(dir);
// 		auto targetHex = state.hexes[target];
//
// 		if (targetHex.kind.among(Terrain.BEE, Terrain.HIVE, Terrain.WALL))
// 		{
// 			targetHex.hp--;
// 			if (targetHex.hp <= 0)
// 				targetHex = Hex.init;
//
// 			state.hexes[target] = targetHex;
// 		}
//
// 		status = Status.OK;
// 	}
// }
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

import std.algorithm;

import game;
import map;
//
// class Order
// {
// 	enum Status
// 	{
// 		PENDING,
//
// 		OUT_OF_BOUNDS,
// 		TARGET_OUT_OF_BOUNDS,
// 		BAD_UNIT,
// 		BAD_PLAYER,
//
// 		BLOCKED,
// 		DESTROYED,
//
// 		OK
// 	}
//
// 	Status status;
// 	ubyte player;
// 	Coords coords;
//
// 	void validate(GameState state)
// 	{
// 		if (coords !in state.hexes)
// 			status = Status.OUT_OF_BOUNDS;
//
// 		checkUnitType(state);
//
// 		if (state.hexes[coords].player != player)
// 			status = Status.BAD_PLAYER;
// 	}
//
// 	void checkUnitType(GameState state)
// 	{
// 		if (state.hexes[coords].kind != Terrain.BEE)
// 			status = Status.BAD_UNIT;
// 	}
//
// 	abstract void apply(GameState state);
// }
//
// class TargetOrder : Order
// {
// 	Direction dir;
//
// 	override void validate(GameState state)
// 	{
// 		super.validate(state);
//
// 		if (coords.neighbour(dir) !in state.hexes)
// 			status = Status.TARGET_OUT_OF_BOUNDS;
// 	}
// }
//
// class MoveOrder : TargetOrder
// {
// 	override void apply(GameState state)
// 	{
// 		auto target = coords.neighbour(dir);
// 		auto targetHex = state.hexes[target];
//
// 		if (targetHex.kind != Terrain.EMPTY)
// 		{
// 			status = Status.BLOCKED;
// 			return;
// 		}
//
// 		state.hexes[target] = state.hexes[coords];
// 		state.hexes[coords] = Hex.init;
//
// 		status = Status.OK;
// 	}
// }
//
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
//
// class SpawnOrder : Order
// {
// 	override void checkUnitType(GameState state)
// 	{
// 		if (state.hexes[coords].kind != Terrain.HIVE)
// 			status = Status.BAD_UNIT;
// 	}
// }

import std.algorithm;
import std.array;
import std.conv;

import map;
import order;
import utils;

const ubyte[HexKind] maxHP = [
	HexKind.HIVE: 12,
	HexKind.BEE: 2,
	HexKind.FIELD: 120,
	HexKind.WALL: 6,
	HexKind.EMPTY: 0,
	HexKind.ROCK: 0
];
//
// class Order
// {
// 	enum Kind
// 	{
// 		MOVE,
// 		HIVE,
// 		BUILD,
// 		ATTACK,
// 		FORAGE,
// 		SPAWN
// 	}
//
// 	enum Status
// 	{
// 		PENDING,
//
// 		OUT_OF_BOUNDS,
// 		TARGET_OUT_OF_BOUNDS,
// 		BAD_UNIT,
// 		ENNEMY_UNIT,
//
// 		BLOCKED,
// 		ATTACKED,
// 		DESTROYED,
//
// 		OK
// 	}
//
// 	Status status;
// 	ubyte player;
// 	Kind kind;
// 	Coords coords;
// 	Direction dir;
//
// 	bool isBeeOrder()
// 	{
// 		return kind.among(
// 			Kind.MOVE,
// 			Kind.HIVE,
// 			Kind.BUILD,
// 			Kind.ATTACK,
// 			Kind.FORAGE
// 		) != 0;
// 	}
//
// 	bool isHiveOrder()
// 	{
// 		return kind == Kind.SPAWN;
// 	}
//
// 	bool hasTarget()
// 	{
// 		return kind.among(
// 			Kind.MOVE,
// 			Kind.BUILD,
// 			Kind.ATTACK
// 		) != 0;
// 	}
//
// 	bool isLocal()
// 	{
// 		return !hasTarget;
// 	}
// }

class GameState
{
	ubyte numPlayers;
	Hex[Coords] hexes;
	uint[] flowers;

	static GameState spawn(const Hex[Coords] baseMap, ubyte numPlayers)
	{
		ubyte[] playerMapping;
		assert(numPlayers <= 6);

		switch (numPlayers)
		{
			case 1: playerMapping = [0, 1, 0, 0, 0, 0, 0]; break;
			case 2: playerMapping = [0, 1, 0, 0, 2, 0, 0]; break;
			case 3: playerMapping = [0, 1, 0, 2, 0, 3, 0]; break;
			case 4: playerMapping = [0, 0, 1, 2, 0, 3, 4]; break;
			case 5: playerMapping = [0, 1, 2, 3, 4, 5, 0]; break;
			case 6: playerMapping = [0, 1, 2, 3, 4, 5, 6]; break;
			default: throw new Exception("Invalid player count: " ~ numPlayers.to!string);
		}

		Hex[Coords] hexes;
		foreach (coords, baseHex; baseMap)
		{
			Hex hex = baseHex;

			hex.player = playerMapping[hex.player];
			if (hex.kind.among(HexKind.HIVE, HexKind.BEE) && hex.player == 0)
				hex.kind = HexKind.EMPTY;
			hex.hp = maxHP[hex.kind];

			hexes[coords] = hex;
		}

		auto state = new GameState;
		state.numPlayers = numPlayers;
		state.hexes = hexes;
		state.flowers = new uint[numPlayers + 1];

		return state;
	}

	void applyOrders(Order[] orders)
	{
		foreach(order; orders)
			order.validate(this);

		foreach(order; orders)
			if (order.status == Order.Status.PENDING)
				order.apply(this);
	}
}

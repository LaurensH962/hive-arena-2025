import std.algorithm;
import std.conv;

import map;

class GameState
{
	ubyte numPlayers;
	Hex[Coords] hexes;
	uint[] flowers;

	static GameState spawn(const Hex[Coords] baseMap, ubyte numPlayers)
	{
		ubyte[] playerMapping;
		assert(numPlayers <= 6);

		switch(numPlayers)
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

			hexes[coords] = hex;
		}

		auto state = new GameState;
		state.numPlayers = numPlayers;
		state.hexes = hexes;
		state.flowers = new uint[numPlayers + 1];

		return state;
	}
}

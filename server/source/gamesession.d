import std.random;
import std.conv;
import std.stdio;
import std.exception;
import std.datetime.systime;
import std.format;
import std.file;
import std.regex;
import std.algorithm;
import std.array;
import std.typecons;

import vibe.vibe;

import game;
import terrain;

alias GameID = uint;
alias Token = string;

class Player
{
	PlayerID id;
	string name;
	Token token;
}

class GameSession
{
	GameID id;
	string map;

	SysTime createdDate;

	Token adminToken;
	Token[] playerTokens;

	Player[] players;

	GameState state;

	static Token[] generateTokens(int count)
	{
		bool[Token] tokens;

		while (tokens.length < count)
		{
			auto token = format("%x", uniform!ulong);
			tokens[token] = true;
		}

		return tokens.keys;
	}

	this(GameID id, int numPlayers, MapData map)
	{
		this.id = id;
		this.map = map.name;

		createdDate = Clock.currTime;

		auto tokens = generateTokens(numPlayers + 1);
		adminToken = tokens[0];
		playerTokens = tokens[1 .. $];

		state = new GameState(map, numPlayers);
	}

	Player addPlayer(string name)
	{
		if (full)
			throw new Exception("Game is full");

		auto player = new Player();
		player.id = cast(PlayerID) players.length;
		player.name = name;
		player.token = playerTokens[player.id];

		players ~= player;
		return player;
	}

	bool full()
	{
		return players.length == state.numPlayers;
	}

	Json fullState()
	{
		return state.serializeToJson;
	}

	Json playerView(Token token)
	{
		auto player = cast(PlayerID) playerTokens.countUntil(token);
		return state.playerView(player).serializeToJson;
	}
}

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

struct GameResponse
{
	struct Cell
	{
		uint row, col;
		@byName Terrain terrain;

		@embedNullable Nullable!uint resources;
		@embedNullable Nullable!PlayerID influence;
		@embedNullable Nullable!Entity entity;
	}

	uint turn;

	Cell[] map;
	uint[] playerResources;
	uint lastInfluenceChange;

	PlayerID[] winners;
	bool gameOver;

	this(const GameState state, Nullable!PlayerID player = Nullable!PlayerID.init)
	{
		turn = state.turn;

		if (player.isNull)
			playerResources = state.playerResources.dup;
		else
			playerResources = [state.playerResources[player.get]];

		lastInfluenceChange = state.lastInfluenceChange;

		foreach(coords, terrain; state.staticMap)
		{
			if (!player.isNull && !state.isVisibleBy(coords, player.get))
				continue;

			auto cell = Cell(
				coords.row,
				coords.col,
				terrain
			);

			if (terrain == Terrain.FIELD)
				cell.resources = state.mapResources[coords];

			if (coords in state.influence)
				cell.influence = state.influence[coords];

			if (coords in state.entities)
				cell.entity = cast(Entity) state.entities[coords];

			map ~= cell;
		}

		winners = state.winners.dup;
		gameOver = state.gameOver;
	}
}

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
		return GameResponse(state).serializeToJson;
	}

	Json playerView(Token token)
	{
		auto player = cast(PlayerID) playerTokens.countUntil(token);
		return GameResponse(state, nullable(player)).serializeToJson;
	}
}

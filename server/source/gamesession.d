import std.algorithm;
import std.random;

import vibe.vibe;

import game;
import terrain;

const TURN_TIMEOUT = 5.seconds;

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
	Order[][] pendingOrders;
	bool[] playedTurn;
	bool[] pulledState;

	Order[][] orderHistory;

	WebSocket[] sockets;

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
		startTurn();
	}

	Player getPlayer(Token token)
	{
		auto id = playerTokens.countUntil(token);
		return (id >= 0) ? players[id] : null;
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

	private void startTurn()
	{
		pendingOrders = new Order[][state.numPlayers];
		playedTurn = new bool[state.numPlayers];
		pulledState = new bool[state.numPlayers];

		setTimer(TURN_TIMEOUT, () => timeoutTurn(state.turn));
	}

	Json fullState()
	{
		return state.serializeToJson;
	}

	Json playerView(Player player)
	{
		return state.playerView(player.id).serializeToJson;
	}

	void setOrders(PlayerID id, Order[] orders)
	{
		assert(pendingOrders.length == state.numPlayers);

		pendingOrders[id] = orders;
		playedTurn[id] = true;

		if (playedTurn.all)
			processTurn();
	}

	private void timeoutTurn(uint turn)
	{
		if (state.turn == turn)
			processTurn();
	}

	struct WebSocketMessage
	{
		uint turn;
		bool gameOver;
	}

	private void processTurn()
	{
		if (state.gameOver)
			return;

		logInfo("Processing orders for game %d, turn %d", id, state.turn);

		auto results = state.processOrders(pendingOrders);
		orderHistory ~= results;

		foreach (socket; sockets)
			if (socket.connected)
				socket.send(WebSocketMessage(state.turn, state.gameOver).serializeToJsonString);

		if (!state.gameOver)
			startTurn();
	}
}

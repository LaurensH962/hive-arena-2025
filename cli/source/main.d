import std.stdio;
import std.json;
import std.getopt;
import std.algorithm;
import std.array;

import vibe.data.json;

import game;
import terrain;

struct ProcessInput
{
	GameState state;
	Order[][] orders;
}

struct ProcessOutput
{
	GameState state;
	Order[] processed;
}

void process(Json data)
{
	auto input = data.deserializeJson!ProcessInput;

	if (input.orders.length != input.state.numPlayers)
		throw new Exception("Player count mismatch");

	auto processed = input.state.processOrders(input.orders);

	auto output = ProcessOutput(input.state, processed);
	writeln(output.serializeToJson);
}

void main(string[] args)
{
	string mapPath;
	ubyte players;
	string toProcess;
	bool help;

	getopt(args,
		"map", &mapPath,
		"players", &players,
		"process", &toProcess,
		"help", &help
	);

	if (help)
	{
		writeln("Usage:");
		writeln(args[0], " --map=<map file> --players=<number of players to spawn>");
		writeln(args[0], " --process=<json formatted game state and orders>");
		writeln("Without arguments, process standard input");

		return;
	}

	if (mapPath.length != 0)
	{
		auto map = loadMap(mapPath);
		auto game = new GameState(map, players);

		writeln(game.serializeToJson);
		return;
	}

	Json data;

	if (toProcess.length != 0)
	{
		import std.file;

		auto txt = readText(toProcess);
		data = parseJsonString(txt);
	}
	else
	{
		string[] input;
		foreach (string line; lines(stdin))
			input ~= line;

		string txt = input.join;
		data = parseJsonString(txt);
	}

	try
	{
		process(data);
	}
	catch (Exception e)
	{
		stderr.writeln(e);
	}
}

import std.stdio;
import std.algorithm;
import std.range;

import game;
import terrain;
import order;

void main()
{
	auto map = loadMap("map.txt");
	auto game = new GameState(map[0], map[1], 3);

	auto move1 = new AttackOrder(game, player: 1, Coords(11, 3), Direction.SE);
	auto move2 = new AttackOrder(game, player: 1, Coords(13, 3), Direction.NE);

	move1.apply();
	move2.apply();

	writeln(game);

	writeln("This is the server!");
}

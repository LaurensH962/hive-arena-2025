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

	auto pos = Coords(12, 4);
	auto move = new MoveOrder();
	move.player = 1;
	move.coords = pos;
	move.direction = Direction.SE;

	auto bee = cast(Bee) game.getEntityAt(pos);

	move.apply(game);
	writeln(move.status);

	writeln(game);
}

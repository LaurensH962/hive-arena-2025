import std.stdio;
import map;

void main()
{
	auto map = loadMap("map.txt");
	write(map.mapToString);
}

package main

import (
	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
)

import . "hive-arena/common"

var TerrainTiles map[Terrain]*ebiten.Image
var EntityTiles map[EntityType]*ebiten.Image

func LoadResources() {
	TerrainTiles = make(map[Terrain]*ebiten.Image)

	TerrainTiles[EMPTY], _, _ = ebitenutil.NewImageFromFile("tile-empty.png")
	TerrainTiles[ROCK], _, _ = ebitenutil.NewImageFromFile("tile-rock.png")
	TerrainTiles[FIELD], _, _ = ebitenutil.NewImageFromFile("tile-field.png")

	EntityTiles = make(map[EntityType]*ebiten.Image)

	EntityTiles[BEE], _, _ = ebitenutil.NewImageFromFile("bee.png")
	EntityTiles[HIVE], _, _ = ebitenutil.NewImageFromFile("hive.png")
}

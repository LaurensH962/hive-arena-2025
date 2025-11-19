package main

import (
	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
)

import . "hive-arena/common"

var TerrainTiles map[Terrain]*ebiten.Image

func LoadResources() {
	TerrainTiles = make(map[Terrain]*ebiten.Image)

	TerrainTiles[EMPTY], _, _ = ebitenutil.NewImageFromFile("tile-empty.png")
	TerrainTiles[ROCK], _, _ = ebitenutil.NewImageFromFile("tile-rock.png")
	TerrainTiles[FIELD], _, _ = ebitenutil.NewImageFromFile("tile-field.png")
}

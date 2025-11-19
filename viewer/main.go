package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"github.com/hajimehoshi/ebiten/v2"
	//		"github.com/hajimehoshi/ebiten/v2/inpututil"
	"io"
	"net/http"
	"slices"
)

import . "hive-arena/common"

const Dx = 32
const Dy = 16

var Tile1 *ebiten.Image

type Viewer struct {
	Game   *PersistedGame
	Cx, Cy float64
	Scale  float64
}

func (viewer *Viewer) Update() error {

	_, dy := ebiten.Wheel()
	if dy > 0 {
		viewer.Scale *= 1.5
	} else if dy < 0 {
		viewer.Scale /= 1.5
	}

	return nil
}

type CoordHex struct {
	Coords Coords
	Hex    *Hex
}

func (viewer *Viewer) DrawState(screen *ebiten.Image, state *GameState) {
	hexes := []CoordHex{}
	for coords, hex := range state.Hexes {
		hexes = append(hexes, CoordHex{coords, hex})
	}
	slices.SortFunc(hexes, func(a, b CoordHex) int {
		return a.Coords.Row - b.Coords.Row
	})

	w, h := ebiten.WindowSize()

	for _, hex := range hexes {
		opt := ebiten.DrawImageOptions{}
		opt.GeoM.Translate(
			float64(Dx*hex.Coords.Col/2-Dx/2)-Dx*viewer.Cx/2,
			float64(Dy*hex.Coords.Row-Dy/2)-Dy*viewer.Cy,
		)
		opt.GeoM.Scale(viewer.Scale, viewer.Scale)
		opt.GeoM.Translate(float64(w)/2, float64(h)/2)
		screen.DrawImage(TerrainTiles[hex.Hex.Terrain], &opt)
	}
}

func (viewer *Viewer) Draw(screen *ebiten.Image) {
	viewer.DrawState(screen, viewer.Game.History[0].State)
}

func (viewer *Viewer) Layout(outsideWidth, outsideHeight int) (screenWidth, screenHeight int) {
	return outsideWidth, outsideHeight
}

func GetURL(url string) *PersistedGame {
	res, err := http.Get(url)
	if err != nil {
		fmt.Println(err)
		return nil
	}

	body, err := io.ReadAll(res.Body)
	res.Body.Close()

	if res.StatusCode > 299 {
		fmt.Printf("Response failed with status code: %d and\nbody: %s\n", res.StatusCode, body)
		return nil
	}

	if err != nil {
		fmt.Println(err)
		return nil
	}

	var game PersistedGame
	err = json.Unmarshal(body, &game)

	if err != nil {
		fmt.Println(err)
		return nil
	}

	return &game
}

func CenterTile(state *GameState) (int, int) {
	cx, cy := 0, 0
	count := 0
	for coords, _ := range state.Hexes {
		cx += coords.Col
		cy += coords.Row
		count++
	}
	return cx / count, cy / count
}

func main() {
	url := flag.String("url", "", "URL of the history file to view")
	flag.Parse()

	if *url == "" {
		flag.PrintDefaults()
		return
	}

	game := GetURL(*url)
	if game == nil {
		return
	}

	cx, cy := CenterTile(game.History[0].State)

	LoadResources()

	ebiten.SetWindowSize(1024, 768)
	ebiten.SetWindowTitle("Hive Arena Viewer")
	ebiten.SetWindowResizingMode(ebiten.WindowResizingModeEnabled)

	viewer := &Viewer{
		Game:  game,
		Cx:    float64(cx),
		Cy:    float64(cy),
		Scale: 1.0,
	}
	err := ebiten.RunGame(viewer)

	if err != nil {
		fmt.Println(err)
	}
}

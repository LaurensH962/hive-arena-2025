package main

import (
	"flag"
	"fmt"
	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	"image/color"
	"slices"
)

import . "hive-arena/common"

const Dx = 32
const Dy = 16

var PlayerColors = []color.Color{
	color.RGBA{255, 100, 100, 255},
	color.RGBA{255, 255, 100, 255},
	color.RGBA{100, 255, 100, 255},
	color.RGBA{100, 255, 255, 255},
	color.RGBA{100, 100, 255, 255},
	color.RGBA{255, 100, 255, 255},
}

type Viewer struct {
	Game *PersistedGame
	Turn int

	Cx, Cy float64
	Scale  float64

	Live 	*LiveGame
}

func (viewer *Viewer) Update() error {

	_, dy := ebiten.Wheel()
	if dy > 0 {
		viewer.Scale *= 1.5
	} else if dy < 0 {
		viewer.Scale /= 1.5
	}

	if inpututil.IsMouseButtonJustPressed(ebiten.MouseButtonLeft) {
		x, y := ebiten.CursorPosition()
		m := viewer.CoordsToTransform(Coords{0, 0})
		m.Invert()
		tx, ty := m.Apply(float64(x), float64(y))
		viewer.Cx = tx / Dx * 2
		viewer.Cy = ty / Dy
	}

	if inpututil.IsKeyJustPressed(ebiten.KeyRight) && viewer.Turn < len(viewer.Game.History)-1 {
		viewer.Turn++
	}

	if inpututil.IsKeyJustPressed(ebiten.KeyLeft) && viewer.Turn > 0 {
		viewer.Turn--
	}

	if inpututil.IsKeyJustPressed(ebiten.KeyUp) {
		viewer.Turn = 0
	}

	if inpututil.IsKeyJustPressed(ebiten.KeyDown) {
		viewer.Turn = len(viewer.Game.History) - 1
	}

	if viewer.Live != nil {
		select {
			case turn := <-viewer.Live.Channel:
				fmt.Printf("Turn %d\n", turn)

				state := getState(viewer.Live.Host, viewer.Live.Id, viewer.Live.Token)
				if state != nil {
					viewer.Game.History = append(viewer.Game.History, Turn{nil, state})
					if viewer.Turn == len(viewer.Game.History) - 2 {
						viewer.Turn++
					}
				}
			default:
		}
	}

	return nil
}

type CoordHex struct {
	Coords Coords
	Hex    *Hex
}

func (viewer *Viewer) CoordsToTransform(coords Coords) ebiten.GeoM {
	m := ebiten.GeoM{}
	w, h := ebiten.WindowSize()

	m.Translate(
		float64(Dx*coords.Col/2-Dx/2)-Dx*viewer.Cx/2,
		float64(Dy*coords.Row-Dy/2)-Dy*viewer.Cy,
	)
	m.Scale(viewer.Scale, viewer.Scale)
	m.Translate(float64(w)/2, float64(h)/2)

	return m
}

func (viewer *Viewer) DrawState(screen *ebiten.Image) {
	state := viewer.Game.History[viewer.Turn].State

	hexes := []CoordHex{}
	for coords, hex := range state.Hexes {
		hexes = append(hexes, CoordHex{coords, hex})
	}
	slices.SortFunc(hexes, func(a, b CoordHex) int {
		return a.Coords.Row - b.Coords.Row
	})

	for _, hex := range hexes {
		opt := ebiten.DrawImageOptions{}
		opt.GeoM = viewer.CoordsToTransform(hex.Coords)

		if hex.Hex.Terrain == FIELD && hex.Hex.Resources == 0 {
			screen.DrawImage(EmptyFieldTile, &opt)
		} else {
			screen.DrawImage(TerrainTiles[hex.Hex.Terrain], &opt)
		}
	}

	for _, hex := range hexes {
		entity := hex.Hex.Entity
		if entity == nil {
			continue
		}

		opt := ebiten.DrawImageOptions{}
		opt.GeoM = viewer.CoordsToTransform(hex.Coords)
		opt.GeoM.Translate(0, -EntityOffset[entity.Type]*viewer.Scale)
		opt.ColorScale.ScaleWithColor(PlayerColors[entity.Player])
		screen.DrawImage(EntityTiles[entity.Type], &opt)
	}

	txt := fmt.Sprintf("%s (%s) %v\nTurn: %d\nPlayers: %v\nResources: %v\nGame over: %v",
		viewer.Game.Id,
		viewer.Game.Map,
		viewer.Game.CreatedDate,
		state.Turn,
		viewer.Game.Players,
		state.PlayerResources,
		state.GameOver,
	)
	ebitenutil.DebugPrint(screen, txt)
}

func (viewer *Viewer) Draw(screen *ebiten.Image) {
	if len(viewer.Game.History) > 0 {
		viewer.DrawState(screen)
	} else {
		txt := fmt.Sprintf("%s has not started yet", viewer.Game.Id)
		ebitenutil.DebugPrint(screen, txt)
	}
}

func (viewer *Viewer) Layout(outsideWidth, outsideHeight int) (screenWidth, screenHeight int) {
	return outsideWidth, outsideHeight
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
	file := flag.String("file", "", "path to the history file to view")
	host := flag.String("host", "", "host for the live game to watch")
	gameId := flag.String("id", "", "ID of the live game to watch")
	token := flag.String("token", "", "access token for the live game to watch")
	flag.Parse()

	var game *PersistedGame
	var live *LiveGame
	if *url != "" {
		game = GetURL(*url)
	} else if *file != "" {
		game = GetFile(*file)
	} else if *host != "" && *gameId != "" && *token != "" {
		game, live = StartLiveWatch(*host, *gameId, *token)

	} else {
		flag.PrintDefaults()
		return
	}

	if game == nil {
		return
	}

	var cx, cy int
	if len(game.History) > 0 {
		cx, cy = CenterTile(game.History[0].State)
	}

	LoadResources()

	ebiten.SetWindowSize(1024, 768)
	ebiten.SetWindowTitle("Hive Arena Viewer")
	ebiten.SetWindowResizingMode(ebiten.WindowResizingModeEnabled)

	viewer := &Viewer{
		Game:  game,
		Cx:    float64(cx),
		Cy:    float64(cy),
		Scale: 1.0,
		Live: live,
	}
	err := ebiten.RunGame(viewer)

	if err != nil {
		fmt.Println(err)
	}
}

/-
  Tests for Worldmap.Viewport
-/
import Crucible
import Worldmap.Viewport

namespace WorldmapTests.ViewportTests

open Crucible
open Worldmap

testSuite "Viewport"

def testViewport : MapViewport := {
  centerLat := 37.7749
  centerLon := -122.4194
  zoom := 12
  screenWidth := 1280
  screenHeight := 720
  tileSize := 512
}

test "visibleTiles returns non-empty list" := do
  let tiles := testViewport.visibleTiles
  shouldSatisfy (tiles.length > 0) "has visible tiles"

test "visibleTiles all have correct zoom level" := do
  let tiles := testViewport.visibleTiles
  shouldSatisfy (tiles.all fun t => t.z == testViewport.zoom) "all at correct zoom"

test "visibleTiles covers center tile" := do
  let tiles := testViewport.visibleTiles
  let centerTile := latLonToTile { lat := testViewport.centerLat, lon := testViewport.centerLon } testViewport.zoom
  shouldSatisfy (tiles.any fun t => t == centerTile) "includes center tile"

test "visibleTilesWithBuffer returns more tiles than visibleTiles" := do
  let normal := testViewport.visibleTiles
  let buffered := testViewport.visibleTilesWithBuffer 2
  shouldSatisfy (buffered.length >= normal.length) "buffered >= normal"

test "visibleTileSet contains visible tiles" := do
  let tiles := testViewport.visibleTiles
  let tileSet := testViewport.visibleTileSet 0
  shouldSatisfy (tiles.all fun t => tileSet.contains t) "set contains all visible"

test "centerTilePos returns fractional position" := do
  let (cx, cy) := testViewport.centerTilePos
  -- At zoom 12, there are 4096 tiles per axis
  shouldSatisfy (cx > 0.0 && cx < 4096.0) "cx in range"
  shouldSatisfy (cy > 0.0 && cy < 4096.0) "cy in range"

test "tileScreenPos places center tile near screen center" := do
  let centerTile := latLonToTile { lat := testViewport.centerLat, lon := testViewport.centerLon } testViewport.zoom
  let (x, y) := testViewport.tileScreenPos centerTile
  let halfWidth := testViewport.screenWidth / 2
  let halfHeight := testViewport.screenHeight / 2
  -- The tile should be near the center (within one tile size)
  shouldSatisfy (intMax (x - halfWidth) (halfWidth - x) < testViewport.tileSize) "x near center"
  shouldSatisfy (intMax (y - halfHeight) (halfHeight - y) < testViewport.tileSize) "y near center"

test "pixelsToDegrees returns reasonable values" := do
  let (dLon, dLat) := testViewport.pixelsToDegrees 100.0 100.0
  -- At zoom 12, 100 pixels should be a small fraction of a degree
  shouldSatisfy (Float.abs dLon < 1.0) "dLon < 1"
  shouldSatisfy (Float.abs dLat < 1.0) "dLat < 1"

test "pixelsToDegrees zero input gives zero output" := do
  let (dLon, dLat) := testViewport.pixelsToDegrees 0.0 0.0
  shouldBe dLon 0.0
  shouldBe dLat 0.0

test "visibleTiles y coordinates are valid" := do
  let tiles := testViewport.visibleTiles
  let maxY := tilesAtZoom testViewport.zoom - 1
  shouldSatisfy (tiles.all fun t => t.y >= 0 && t.y <= maxY) "y coords valid"

test "visibleTiles x coordinates wrap correctly" := do
  -- Create a viewport near the date line
  let dateLineViewport : MapViewport := {
    centerLat := 0.0
    centerLon := 179.0
    zoom := 5
    screenWidth := 1280
    screenHeight := 720
    tileSize := 512
  }
  let tiles := dateLineViewport.visibleTiles
  -- All x coordinates should be valid (0 to 2^zoom - 1)
  let maxX := tilesAtZoom 5 - 1
  shouldSatisfy (tiles.all fun t => t.x >= 0 && t.x <= maxX) "x coords valid"

test "visibleTilesWithFallbacks includes parent tiles" := do
  let vp : MapViewport := { testViewport with zoom := 10 }
  let withFallbacks := vp.visibleTileSetWithFallbacks 1
  let visibleTiles := vp.visibleTilesWithBuffer 1
  -- Check that parent tiles are included
  let hasParent := visibleTiles.any fun t =>
    withFallbacks.contains t.parentTile
  shouldBe hasParent true



end WorldmapTests.ViewportTests

/-
  Tests for Worldmap.TileCoord
-/
import Crucible
import Worldmap.TileCoord

namespace WorldmapTests.TileCoordTests

open Crucible
open Worldmap

testSuite "TileCoord"

test "latLonToTile at zoom 0 returns single tile" := do
  let tile := latLonToTile { lat := 0.0, lon := 0.0 } 0
  shouldBe tile.z 0
  shouldBe tile.x 0
  shouldBe tile.y 0

test "latLonToTile at zoom 1 returns correct quadrant" := do
  -- Northwest quadrant
  let nw := latLonToTile { lat := 45.0, lon := -90.0 } 1
  shouldBe nw.z 1
  shouldBe nw.x 0
  shouldBe nw.y 0

  -- Southeast quadrant
  let se := latLonToTile { lat := -45.0, lon := 90.0 } 1
  shouldBe se.z 1
  shouldBe se.x 1
  shouldBe se.y 1

test "tileToLatLon returns northwest corner" := do
  let pos := tileToLatLon { x := 0, y := 0, z := 0 }
  -- At zoom 0, tile (0,0) covers the whole world
  -- Northwest corner should be around lat 85, lon -180
  shouldSatisfy (pos.lat > 80.0) "latitude > 80"
  shouldBe pos.lon (-180.0)

test "latLonToTile and tileToLatLon are approximately inverse" := do
  let original : LatLon := { lat := 37.7749, lon := -122.4194 }  -- San Francisco
  let tile := latLonToTile original 10
  let recovered := tileToLatLon tile
  -- The tile corner should be close to but not exactly the original
  -- (within one tile's worth of latitude/longitude)
  let latDiff := Float.abs (original.lat - recovered.lat)
  let lonDiff := Float.abs (original.lon - recovered.lon)
  shouldSatisfy (latDiff < 1.0) "lat diff < 1.0"
  shouldSatisfy (lonDiff < 1.0) "lon diff < 1.0"

-- Helper to check if a string contains a substring
def containsSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

test "tileUrl generates valid CartoDB URL" := do
  let tile : TileCoord := { x := 1234, y := 5678, z := 12 }
  let url := tileUrl tile
  shouldSatisfy (containsSubstr url "basemaps.cartocdn.com") "contains cartocdn"
  shouldSatisfy (containsSubstr url "/12/1234/5678@2x.png") "contains tile path"

test "tileUrl rotates through subdomains" := do
  -- Different tile coords should potentially use different subdomains
  let url1 := tileUrl { x := 0, y := 0, z := 10 }
  let url2 := tileUrl { x := 1, y := 0, z := 10 }
  let url3 := tileUrl { x := 2, y := 0, z := 10 }
  let url4 := tileUrl { x := 3, y := 0, z := 10 }
  -- All should be valid URLs (contain the cartocdn domain)
  shouldSatisfy (containsSubstr url1 "basemaps.cartocdn.com") "url1 valid"
  shouldSatisfy (containsSubstr url2 "basemaps.cartocdn.com") "url2 valid"
  shouldSatisfy (containsSubstr url3 "basemaps.cartocdn.com") "url3 valid"
  shouldSatisfy (containsSubstr url4 "basemaps.cartocdn.com") "url4 valid"

test "tilesAtZoom returns correct count" := do
  shouldBe (tilesAtZoom 0) 1
  shouldBe (tilesAtZoom 1) 2
  shouldBe (tilesAtZoom 2) 4
  shouldBe (tilesAtZoom 10) 1024

test "parentTile returns correct parent" := do
  let child : TileCoord := { x := 10, y := 20, z := 5 }
  let parent := child.parentTile
  shouldBe parent.z 4
  shouldBe parent.x 5
  shouldBe parent.y 10

test "childTiles returns 4 children" := do
  let parent : TileCoord := { x := 5, y := 10, z := 4 }
  let children := parent.childTiles
  shouldBe children.size 4
  -- All children should be at zoom z+1
  shouldSatisfy (children.all fun c => c.z == 5) "all at zoom 5"
  -- Children should have correct coordinates
  shouldBe (children[0]!.x, children[0]!.y) (10, 20)
  shouldBe (children[1]!.x, children[1]!.y) (11, 20)
  shouldBe (children[2]!.x, children[2]!.y) (10, 21)
  shouldBe (children[3]!.x, children[3]!.y) (11, 21)

test "parentTile of childTiles returns original" := do
  let original : TileCoord := { x := 7, y := 13, z := 8 }
  let children := original.childTiles
  -- All children should have the same parent
  shouldSatisfy (children.all fun c => c.parentTile == original) "all have same parent"

test "zoom 0 tile covers entire world" := do
  -- Point at various locations should all map to (0,0) at zoom 0
  let sf := latLonToTile { lat := 37.77, lon := -122.42 } 0
  let tokyo := latLonToTile { lat := 35.68, lon := 139.69 } 0
  let london := latLonToTile { lat := 51.51, lon := -0.13 } 0
  shouldBe sf { x := 0, y := 0, z := 0 }
  shouldBe tokyo { x := 0, y := 0, z := 0 }
  shouldBe london { x := 0, y := 0, z := 0 }

test "date line handling" := do
  -- Points near the date line (lon = 180 / -180)
  let east := latLonToTile { lat := 0.0, lon := 179.0 } 2
  let west := latLonToTile { lat := 0.0, lon := -179.0 } 2
  -- These should be in different tiles (wrap around)
  shouldBe east.x 3
  shouldBe west.x 0

#generate_tests

end WorldmapTests.TileCoordTests

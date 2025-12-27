/-
  Tests for Worldmap.Zoom
-/
import Crucible
import Worldmap.Zoom

namespace WorldmapTests.ZoomTests

open Crucible
open Worldmap
open Worldmap.Zoom

testSuite "Zoom"

def zoomTestViewport : MapViewport := {
  centerLat := 37.7749
  centerLon := -122.4194
  zoom := 12
  screenWidth := 1280
  screenHeight := 720
  tileSize := 512
}

test "screenToTile at screen center returns center tile" := do
  let (cx, cy) := zoomTestViewport.centerTilePos
  let (tx, ty) := screenToTile zoomTestViewport (intToFloat zoomTestViewport.screenWidth / 2.0) (intToFloat zoomTestViewport.screenHeight / 2.0)
  -- Should be very close to center tile position
  shouldSatisfy (Float.abs (tx - cx) < 0.01) "tx near cx"
  shouldSatisfy (Float.abs (ty - cy) < 0.01) "ty near cy"

test "tileToGeo and screenToGeo at center return viewport center" := do
  let (lat, lon) := screenToGeo zoomTestViewport (intToFloat zoomTestViewport.screenWidth / 2.0) (intToFloat zoomTestViewport.screenHeight / 2.0)
  -- Should be very close to viewport center
  shouldSatisfy (Float.abs (lat - zoomTestViewport.centerLat) < 0.001) "lat near center"
  shouldSatisfy (Float.abs (lon - zoomTestViewport.centerLon) < 0.001) "lon near center"

test "zoomToPoint at screen center doesn't move center" := do
  let cx := intToFloat zoomTestViewport.screenWidth / 2.0
  let cy := intToFloat zoomTestViewport.screenHeight / 2.0
  let zoomed := zoomToPoint zoomTestViewport cx cy (zoomTestViewport.zoom + 1)
  -- Center should be approximately the same
  shouldSatisfy (Float.abs (zoomed.centerLat - zoomTestViewport.centerLat) < 0.0001) "lat unchanged"
  shouldSatisfy (Float.abs (zoomed.centerLon - zoomTestViewport.centerLon) < 0.0001) "lon unchanged"

test "zoomToPoint increases zoom level" := do
  let zoomed := zoomToPoint zoomTestViewport 640.0 360.0 (zoomTestViewport.zoom + 1)
  shouldBe zoomed.zoom (zoomTestViewport.zoom + 1)

test "zoomToPoint decreases zoom level" := do
  let zoomed := zoomToPoint zoomTestViewport 640.0 360.0 (zoomTestViewport.zoom - 1)
  shouldBe zoomed.zoom (zoomTestViewport.zoom - 1)

test "zoomToPoint clamps to max zoom" := do
  let zoomed := zoomToPoint zoomTestViewport 640.0 360.0 25
  shouldBe zoomed.zoom 19

test "zoomToPoint clamps to min zoom" := do
  let zoomed := zoomToPoint zoomTestViewport 640.0 360.0 (-5)
  shouldBe zoomed.zoom 0

test "zoomToPoint clamps latitude" := do
  -- Create viewport near pole
  let polarVp : MapViewport := { zoomTestViewport with centerLat := 84.0 }
  let zoomed := zoomToPoint polarVp 0.0 0.0 (polarVp.zoom + 3)
  -- Latitude should be clamped to max Mercator range
  shouldSatisfy (zoomed.centerLat <= 85.0) "lat <= 85"
  shouldSatisfy (zoomed.centerLat >= -85.0) "lat >= -85"

test "zoomToPoint wraps longitude" := do
  -- Create viewport near date line
  let dateLineVp : MapViewport := { zoomTestViewport with centerLon := 179.0 }
  let zoomed := zoomToPoint dateLineVp 1280.0 360.0 (dateLineVp.zoom + 1)
  -- Longitude should be wrapped to valid range
  shouldSatisfy (zoomed.centerLon >= -180.0 && zoomed.centerLon <= 180.0) "lon in range"

test "geoToTileFrac and tileToGeoFrac are inverse" := do
  let lat := 40.0
  let lon := -74.0
  let zoom := 10.5
  let (tx, ty) := geoToTileFrac lat lon zoom
  let (lat2, lon2) := tileToGeoFrac tx ty zoom
  shouldSatisfy (Float.abs (lat - lat2) < 0.0001) "lat round-trip"
  shouldSatisfy (Float.abs (lon - lon2) < 0.0001) "lon round-trip"

test "centerForAnchor keeps anchor point fixed" := do
  let anchorLat := 37.8
  let anchorLon := -122.4
  let anchorScreenX := 800.0
  let anchorScreenY := 400.0
  let displayZoom := 12.5
  let (newLat, newLon) := centerForAnchor anchorLat anchorLon anchorScreenX anchorScreenY
      zoomTestViewport.screenWidth zoomTestViewport.screenHeight zoomTestViewport.tileSize displayZoom
  -- The anchor point should still map to the same screen position
  -- Convert anchor back to screen coords (approximately)
  let (anchorTileX, anchorTileY) := geoToTileFrac anchorLat anchorLon displayZoom
  let (centerTileX, centerTileY) := geoToTileFrac newLat newLon displayZoom
  let screenX := (anchorTileX - centerTileX) * (intToFloat zoomTestViewport.tileSize) + (intToFloat zoomTestViewport.screenWidth / 2.0)
  let screenY := (anchorTileY - centerTileY) * (intToFloat zoomTestViewport.tileSize) + (intToFloat zoomTestViewport.screenHeight / 2.0)
  shouldSatisfy (Float.abs (screenX - anchorScreenX) < 1.0) "screenX near anchor"
  shouldSatisfy (Float.abs (screenY - anchorScreenY) < 1.0) "screenY near anchor"

test "tileToGeo returns valid coordinates" := do
  let (lat, lon) := tileToGeo 500.0 500.0 10
  shouldSatisfy (lat >= -90.0 && lat <= 90.0) "lat in range"
  shouldSatisfy (lon >= -180.0 && lon <= 180.0) "lon in range"

#generate_tests

end WorldmapTests.ZoomTests

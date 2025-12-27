/-
  Tests for Worldmap.Marker
-/
import Crucible
import Worldmap.Marker
import Worldmap.Viewport

namespace WorldmapTests.MarkerTests

open Crucible
open Worldmap

testSuite "Marker"

-- ============================================================================
-- MarkerColor Tests
-- ============================================================================

test "MarkerColor preset colors have correct values" := do
  shouldBe MarkerColor.red.r 1.0
  shouldBe MarkerColor.red.g 0.0
  shouldBe MarkerColor.red.b 0.0
  shouldBe MarkerColor.green.g 0.8
  shouldBe MarkerColor.blue.b 1.0

test "MarkerColor.withAlpha modifies alpha" := do
  let c := MarkerColor.red.withAlpha 0.5
  shouldBe c.a 0.5
  shouldBe c.r 1.0  -- Other components unchanged

-- ============================================================================
-- Marker Construction Tests
-- ============================================================================

test "Marker.simple creates marker at coordinates" := do
  let m := Marker.simple 1 37.7749 (-122.4194)
  shouldBe m.id 1
  shouldBe m.lat 37.7749
  shouldBe m.lon (-122.4194)
  shouldBe m.label none

test "Marker.labeled creates marker with label" := do
  let m := Marker.labeled 2 40.7128 (-74.0060) "New York"
  shouldBe m.id 2
  shouldBe m.label (some "New York")

test "Marker.colored creates marker with color" := do
  let m := Marker.colored 3 51.5074 (-0.1278) MarkerColor.blue
  shouldBe m.id 3
  shouldBe m.color MarkerColor.blue

-- ============================================================================
-- MarkerLayer Basic Tests
-- ============================================================================

test "MarkerLayer.empty has no markers" := do
  let layer := MarkerLayer.empty
  shouldBe layer.count 0
  shouldBe layer.visible true

test "MarkerLayer.addMarker increases count" := do
  let layer := MarkerLayer.empty
  let (layer, _) := layer.addMarker 37.7749 (-122.4194)
  shouldBe layer.count 1

test "MarkerLayer.addMarker returns unique ids" := do
  let layer := MarkerLayer.empty
  let (layer, id1) := layer.addMarker 37.7749 (-122.4194)
  let (layer, id2) := layer.addMarker 40.7128 (-74.0060)
  shouldSatisfy (id1 != id2) "ids are unique"
  shouldBe layer.count 2

test "MarkerLayer.removeMarker decreases count" := do
  let layer := MarkerLayer.empty
  let (layer, id) := layer.addMarker 37.7749 (-122.4194)
  let layer := layer.removeMarker id
  shouldBe layer.count 0

test "MarkerLayer.clearMarkers removes all" := do
  let layer := MarkerLayer.empty
  let (layer, _) := layer.addMarker 37.7749 (-122.4194)
  let (layer, _) := layer.addMarker 40.7128 (-74.0060)
  let (layer, _) := layer.addMarker 51.5074 (-0.1278)
  let layer := layer.clearMarkers
  shouldBe layer.count 0

test "MarkerLayer.getMarker returns correct marker" := do
  let layer := MarkerLayer.empty
  let (layer, id) := layer.addMarker 37.7749 (-122.4194) (some "SF") MarkerColor.red 15.0
  match layer.getMarker id with
  | some m =>
    shouldBe m.lat 37.7749
    shouldBe m.label (some "SF")
  | none => shouldSatisfy false "marker should be found"

test "MarkerLayer.getMarker returns none for missing id" := do
  let layer := MarkerLayer.empty
  shouldSatisfy (layer.getMarker 999).isNone "should return none for missing id"

-- ============================================================================
-- MarkerLayer Update Tests
-- ============================================================================

test "MarkerLayer.setLabel updates label" := do
  let layer := MarkerLayer.empty
  let (layer, id) := layer.addMarker 37.7749 (-122.4194)
  let layer := layer.setLabel id (some "Updated")
  match layer.getMarker id with
  | some m => shouldBe m.label (some "Updated")
  | none => shouldSatisfy false "marker should be found"

test "MarkerLayer.setColor updates color" := do
  let layer := MarkerLayer.empty
  let (layer, id) := layer.addMarker 37.7749 (-122.4194)
  let layer := layer.setColor id MarkerColor.blue
  match layer.getMarker id with
  | some m => shouldBe m.color MarkerColor.blue
  | none => shouldSatisfy false "marker should be found"

test "MarkerLayer.moveMarker updates position" := do
  let layer := MarkerLayer.empty
  let (layer, id) := layer.addMarker 37.7749 (-122.4194)
  let layer := layer.moveMarker id 40.0 (-120.0)
  match layer.getMarker id with
  | some m =>
    shouldBe m.lat 40.0
    shouldBe m.lon (-120.0)
  | none => shouldSatisfy false "marker should be found"

-- ============================================================================
-- MarkerLayer Visibility Tests
-- ============================================================================

test "MarkerLayer.toggleVisibility toggles state" := do
  let layer := MarkerLayer.empty
  shouldBe layer.visible true
  let layer := layer.toggleVisibility
  shouldBe layer.visible false
  let layer := layer.toggleVisibility
  shouldBe layer.visible true

test "MarkerLayer.setVisibility sets state" := do
  let layer := MarkerLayer.empty
  let layer := layer.setVisibility false
  shouldBe layer.visible false
  let layer := layer.setVisibility true
  shouldBe layer.visible true

-- ============================================================================
-- Viewport Culling Tests
-- ============================================================================

def testViewport : MapViewport := {
  centerLat := 37.7749
  centerLon := -122.4194
  zoom := 12
  screenWidth := 1280
  screenHeight := 720
  tileSize := 512
}

test "markersInView returns markers in viewport" := do
  let layer := MarkerLayer.empty
  let (layer, _) := layer.addMarker 37.7749 (-122.4194)  -- In view (at center)
  let visible := layer.markersInView testViewport
  shouldBe visible.size 1

test "markersInView excludes far markers" := do
  let layer := MarkerLayer.empty
  let (layer, _) := layer.addMarker 0.0 0.0  -- Far away
  let visible := layer.markersInView testViewport
  shouldBe visible.size 0

test "markersInView returns empty when layer hidden" := do
  let layer := MarkerLayer.empty
  let (layer, _) := layer.addMarker 37.7749 (-122.4194)
  let layer := layer.setVisibility false
  let visible := layer.markersInView testViewport
  shouldBe visible.size 0

-- ============================================================================
-- Hit Testing Tests
-- ============================================================================

test "hitTest returns none for empty layer" := do
  let layer := MarkerLayer.empty
  shouldBe (layer.hitTest testViewport 640.0 360.0) none

test "hitTest returns marker id when clicking on marker" := do
  let layer := MarkerLayer.empty
  -- Add marker at viewport center
  let (layer, id) := layer.addMarker 37.7749 (-122.4194) none MarkerColor.red 20.0
  -- Click at screen center (where marker should be)
  let result := layer.hitTest testViewport 640.0 360.0
  shouldBe result (some id)

test "hitTest returns none when missing marker" := do
  let layer := MarkerLayer.empty
  let (layer, _) := layer.addMarker 37.7749 (-122.4194) none MarkerColor.red 10.0
  -- Click far from marker
  let result := layer.hitTest testViewport 0.0 0.0
  shouldBe result none

test "hitTestAll returns all overlapping markers" := do
  let layer := MarkerLayer.empty
  -- Add two markers at same location
  let (layer, id1) := layer.addMarker 37.7749 (-122.4194) none MarkerColor.red 20.0
  let (layer, id2) := layer.addMarker 37.7749 (-122.4194) none MarkerColor.blue 20.0
  -- Click at center
  let results := layer.hitTestAll testViewport 640.0 360.0
  shouldBe results.size 2
  shouldSatisfy (results.contains id1) "contains first marker"
  shouldSatisfy (results.contains id2) "contains second marker"

#generate_tests

end WorldmapTests.MarkerTests

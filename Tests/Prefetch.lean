/-
  Tests for Worldmap.Prefetch
-/
import Crucible
import Worldmap.Prefetch
import Worldmap.State
import Worldmap.Viewport
import Worldmap.TileCache

namespace WorldmapTests.PrefetchTests

open Crucible
open Worldmap

testSuite "Prefetch"

-- ============================================================================
-- PrefetchConfig Tests
-- ============================================================================

test "defaultPrefetchConfig has expected values" := do
  let config := defaultPrefetchConfig
  shouldBe config.lookAheadMs 500.0
  shouldBe config.minVelocity 5.0
  shouldBe config.maxPrefetchTiles 8

test "fastPrefetchConfig has shorter lookahead" := do
  let fast := fastPrefetchConfig
  let default := defaultPrefetchConfig
  shouldSatisfy (fast.lookAheadMs < default.lookAheadMs) "fast has shorter lookahead"
  shouldSatisfy (fast.maxPrefetchTiles > default.maxPrefetchTiles) "fast has more tiles"

test "conservativePrefetchConfig has higher velocity threshold" := do
  let cons := conservativePrefetchConfig
  let default := defaultPrefetchConfig
  shouldSatisfy (cons.minVelocity > default.minVelocity) "conservative has higher threshold"
  shouldSatisfy (cons.maxPrefetchTiles < default.maxPrefetchTiles) "conservative has fewer tiles"

-- ============================================================================
-- Velocity Magnitude Tests
-- ============================================================================

test "velocityMagnitude returns zero for zero velocity" := do
  shouldBe (velocityMagnitude 0.0 0.0) 0.0

test "velocityMagnitude calculates correctly for simple cases" := do
  -- 3-4-5 triangle
  let mag := velocityMagnitude 3.0 4.0
  shouldSatisfy (Float.abs (mag - 5.0) < 0.001) "magnitude should be 5.0"

test "velocityMagnitude handles negative values" := do
  let mag1 := velocityMagnitude (-3.0) 4.0
  let mag2 := velocityMagnitude 3.0 (-4.0)
  shouldSatisfy (Float.abs (mag1 - 5.0) < 0.001) "handles negative x"
  shouldSatisfy (Float.abs (mag2 - 5.0) < 0.001) "handles negative y"

-- ============================================================================
-- shouldPrefetch Tests
-- ============================================================================

def testViewport : MapViewport := {
  centerLat := 37.7749
  centerLon := -122.4194
  zoom := 12
  screenWidth := 1280
  screenHeight := 720
  tileSize := 512
}

test "shouldPrefetch returns false for zero velocity" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 0.0
    panVelocityY := 0.0
  }
  shouldBe (shouldPrefetch state) false

test "shouldPrefetch returns false for low velocity" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 2.0
    panVelocityY := 2.0  -- magnitude ~2.83, below default 5.0
  }
  shouldBe (shouldPrefetch state) false

test "shouldPrefetch returns true for high velocity" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 10.0
    panVelocityY := 10.0  -- magnitude ~14.14, above 5.0
  }
  shouldBe (shouldPrefetch state) true

-- ============================================================================
-- tilesForPrefetch Tests
-- ============================================================================

test "tilesForPrefetch returns empty for zero velocity" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 0.0
    panVelocityY := 0.0
  }
  let tiles := tilesForPrefetch state
  shouldBe tiles.size 0

test "tilesForPrefetch returns tiles for high velocity" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 50.0  -- Strong rightward pan
    panVelocityY := 0.0
  }
  let tiles := tilesForPrefetch state
  -- Should return some tiles in the predicted direction
  shouldSatisfy (tiles.size > 0) "should return prefetch tiles for high velocity"

test "tilesForPrefetch respects maxPrefetchTiles" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 100.0  -- Very high velocity
    panVelocityY := 100.0
  }
  let config : PrefetchConfig := { maxPrefetchTiles := 4 }
  let tiles := tilesForPrefetch state config
  shouldSatisfy (tiles.size <= 4) "should respect maxPrefetchTiles limit"

test "tilesForPrefetch tiles are at correct zoom level" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 50.0
    panVelocityY := 0.0
  }
  let tiles := tilesForPrefetch state
  for tile in tiles do
    shouldBe tile.z 12

-- ============================================================================
-- predictedCenter Tests
-- ============================================================================

test "predictedCenter returns current center for zero velocity" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 0.0
    panVelocityY := 0.0
  }
  let (lat, lon) := predictedCenter state
  shouldSatisfy (Float.abs (lat - 37.7749) < 0.001) "latitude should be unchanged"
  shouldSatisfy (Float.abs (lon - (-122.4194)) < 0.001) "longitude should be unchanged"

test "predictedCenter moves in velocity direction" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 12
    displayZoom := 12.0
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    panVelocityX := 50.0  -- Moving right (east) on screen
    panVelocityY := 0.0
  }
  let (_, lon) := predictedCenter state
  -- When panning right, the center should move west (longitude decreases)
  shouldSatisfy (lon < -122.4194) "center should move west when panning right"



end WorldmapTests.PrefetchTests

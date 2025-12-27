/-
  Tests for Request Coalescing (Zoom Debouncing)
-/
import Crucible
import Worldmap.Render
import Worldmap.State
import Worldmap.Viewport

namespace WorldmapTests.RequestCoalescingTests

open Crucible
open Worldmap

testSuite "RequestCoalescing"

def testViewport : MapViewport := {
  centerLat := 37.7749
  centerLon := -122.4194
  zoom := 12
  screenWidth := 1280
  screenHeight := 720
  tileSize := 512
}

-- ============================================================================
-- shouldFetchNewTiles Tests
-- ============================================================================

test "shouldFetchNewTiles returns true when not animating" := do
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
    isAnimatingZoom := false
    frameCount := 100
    lastZoomChangeFrame := 50
  }
  shouldBe (shouldFetchNewTiles state) true

test "shouldFetchNewTiles returns false during debounce window" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 13
    displayZoom := 12.5
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    isAnimatingZoom := true
    frameCount := 103           -- Only 3 frames since zoom change
    lastZoomChangeFrame := 100
    zoomDebounceFrames := 6     -- Need 6 frames to debounce
  }
  shouldBe (shouldFetchNewTiles state) false

test "shouldFetchNewTiles returns true after debounce window" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 13
    displayZoom := 12.8
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    isAnimatingZoom := true
    frameCount := 110           -- 10 frames since zoom change
    lastZoomChangeFrame := 100
    zoomDebounceFrames := 6     -- Need 6 frames to debounce
  }
  shouldBe (shouldFetchNewTiles state) true

test "shouldFetchNewTiles returns true at exact debounce boundary" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 13
    displayZoom := 12.5
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    isAnimatingZoom := true
    frameCount := 106           -- Exactly 6 frames since zoom change
    lastZoomChangeFrame := 100
    zoomDebounceFrames := 6
  }
  shouldBe (shouldFetchNewTiles state) true

test "shouldFetchNewTiles respects custom debounce frames" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 13
    displayZoom := 12.5
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    isAnimatingZoom := true
    frameCount := 108
    lastZoomChangeFrame := 100
    zoomDebounceFrames := 10    -- Custom: need 10 frames
  }
  shouldBe (shouldFetchNewTiles state) false

test "rapid zoom changes reset debounce timer" := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty {})
  let activeTasks ← IO.mkRef {}
  -- Simulate rapid zoom: user scrolled at frame 100, then again at frame 103
  let state : MapState := {
    viewport := testViewport
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := 14
    displayZoom := 12.8
    initialLat := 37.7749
    initialLon := -122.4194
    initialZoom := 12
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
    isAnimatingZoom := true
    frameCount := 105           -- 2 frames since last zoom change
    lastZoomChangeFrame := 103  -- Last zoom change was at frame 103
    zoomDebounceFrames := 6
  }
  -- Should still be debouncing because lastZoomChangeFrame was reset
  shouldBe (shouldFetchNewTiles state) false

-- ============================================================================
-- Default Debounce Configuration Tests
-- ============================================================================

test "default zoomDebounceFrames is 6" := do
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
  }
  shouldBe state.zoomDebounceFrames 6

test "default lastZoomChangeFrame is 0" := do
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
  }
  shouldBe state.lastZoomChangeFrame 0

#generate_tests

end WorldmapTests.RequestCoalescingTests

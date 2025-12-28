/-
  Complete Map State
  Extracted from Afferent to Worldmap
-/
import Worldmap.TileCache
import Worldmap.TileDiskCache
import Worldmap.TileProvider
import Worldmap.Viewport
import Worldmap.Zoom
import Std.Data.HashMap

namespace Worldmap

open Worldmap (TileDiskCacheConfig TileDiskCacheIndex TileProvider)
open Worldmap (ZoomAnimationConfig MapBounds)

/-- Complete map state -/
structure MapState where
  viewport : MapViewport
  cache : TileCache
  resultQueue : IO.Ref (Array FetchResult)  -- Shared queue for async fetch results
  frameCount : Nat := 0                      -- Abstract time counter for retry scheduling
  isDragging : Bool := false
  dragStartX : Float := 0.0
  dragStartY : Float := 0.0
  dragStartLat : Float := 0.0
  dragStartLon : Float := 0.0
  -- Zoom animation state
  targetZoom : Int                           -- User's desired zoom level
  displayZoom : Float                        -- Current animated zoom (fractional)
  zoomAnchorScreenX : Float := 0.0           -- Screen position to keep fixed
  zoomAnchorScreenY : Float := 0.0
  zoomAnchorLat : Float := 0.0               -- Geographic point to keep fixed
  zoomAnchorLon : Float := 0.0
  isAnimatingZoom : Bool := false            -- Whether animation is in progress
  -- Initial view for Home key reset
  initialLat : Float
  initialLon : Float
  initialZoom : Int
  -- Cursor position (geographic coordinates under mouse)
  cursorLat : Float := 0.0
  cursorLon : Float := 0.0
  cursorScreenX : Float := 0.0
  cursorScreenY : Float := 0.0
  -- Tile provider configuration
  tileProvider : TileProvider := TileProvider.default
  -- Zoom animation configuration
  zoomAnimationConfig : ZoomAnimationConfig := defaultZoomAnimationConfig
  -- Map bounds constraints
  mapBounds : MapBounds := MapBounds.world
  -- Disk cache state
  diskCacheConfig : TileDiskCacheConfig := {}
  diskCacheIndex : IO.Ref TileDiskCacheIndex
  -- Active task cancellation flags
  activeTasks : IO.Ref (Std.HashMap TileCoord (IO.Ref Bool))
  -- Velocity tracking for predictive prefetching
  panVelocityX : Float := 0.0     -- smoothed pixels/frame
  panVelocityY : Float := 0.0
  lastMouseX : Float := 0.0       -- for delta calculation
  lastMouseY : Float := 0.0
  -- Zoom debouncing for request coalescing
  lastZoomChangeFrame : Nat := 0  -- frame when zoom target changed
  zoomDebounceFrames : Nat := 6   -- wait ~100ms at 60fps before fetching

namespace MapState

/-- Initialize map state centered on a location -/
def init (lat lon : Float) (zoom : Int) (width height : Int)
    (diskConfig : TileDiskCacheConfig := {})
    (provider : TileProvider := TileProvider.default)
    (zoomConfig : ZoomAnimationConfig := defaultZoomAnimationConfig)
    (bounds : MapBounds := MapBounds.world) : IO MapState := do
  let queue ← IO.mkRef #[]
  let diskIndex ← IO.mkRef (TileDiskCacheIndex.empty diskConfig)
  let activeTasks ← IO.mkRef {}
  -- Clamp zoom to provider limits and bounds
  let clampedZoom := bounds.clampZoom (intClamp (clampZoom zoom) provider.minZoom provider.maxZoom)
  -- Clamp lat/lon to bounds
  let clampedLat := bounds.clampLat (clampLatitude lat)
  let clampedLon := bounds.clampLon lon
  pure {
    viewport := {
      centerLat := clampedLat
      centerLon := clampedLon
      zoom := clampedZoom
      screenWidth := width
      screenHeight := height
      tileSize := provider.tileSize
    }
    cache := TileCache.empty
    resultQueue := queue
    targetZoom := clampedZoom
    displayZoom := intToFloat clampedZoom
    initialLat := clampedLat
    initialLon := clampedLon
    initialZoom := clampedZoom
    tileProvider := provider
    zoomAnimationConfig := zoomConfig
    mapBounds := bounds
    diskCacheConfig := diskConfig
    diskCacheIndex := diskIndex
    activeTasks := activeTasks
  }

/-- Change the tile provider (clears cache since tiles are different) -/
def setProvider (state : MapState) (provider : TileProvider) : MapState :=
  let clampedZoom := state.mapBounds.clampZoom (intClamp state.viewport.zoom provider.minZoom provider.maxZoom)
  { state with
    tileProvider := provider
    cache := TileCache.empty  -- Clear cache since tiles will be different
    viewport := { state.viewport with
      zoom := clampedZoom
      tileSize := provider.tileSize
    }
    targetZoom := clampedZoom
    displayZoom := intToFloat clampedZoom
  }

/-- Change the zoom animation configuration -/
def setZoomAnimationConfig (state : MapState) (config : ZoomAnimationConfig) : MapState :=
  { state with zoomAnimationConfig := config }

/-- Change the map bounds (clamps current position if outside new bounds) -/
def setBounds (state : MapState) (bounds : MapBounds) : MapState :=
  let clampedLat := bounds.clampLat state.viewport.centerLat
  let clampedLon := bounds.clampLon state.viewport.centerLon
  let clampedZoom := bounds.clampZoom state.viewport.zoom
  { state with
    mapBounds := bounds
    viewport := { state.viewport with
      centerLat := clampedLat
      centerLon := clampedLon
      zoom := clampedZoom
    }
    targetZoom := clampedZoom
    displayZoom := intToFloat clampedZoom
  }

/-- Update viewport center (respects bounds) -/
def setCenter (state : MapState) (lat lon : Float) : MapState :=
  let clampedLat := state.mapBounds.clampLat (clampLatitude lat)
  let clampedLon := state.mapBounds.clampLon lon
  { state with viewport := { state.viewport with
      centerLat := clampedLat
      centerLon := clampedLon
    }
  }

/-- Update zoom level (respects bounds, also updates animation state) -/
def setZoom (state : MapState) (zoom : Int) : MapState :=
  let clamped := state.mapBounds.clampZoom (clampZoom zoom)
  { state with
      viewport := { state.viewport with zoom := clamped }
      targetZoom := clamped
      displayZoom := intToFloat clamped
      isAnimatingZoom := false
  }

/-- Update viewport screen dimensions (for window resize) -/
def updateScreenSize (state : MapState) (width height : Nat) : MapState :=
  { state with viewport := { state.viewport with
      screenWidth := width
      screenHeight := height
    }
  }

/-- Start dragging -/
def startDrag (state : MapState) (mouseX mouseY : Float) : MapState :=
  { state with
    isDragging := true
    dragStartX := mouseX
    dragStartY := mouseY
    dragStartLat := state.viewport.centerLat
    dragStartLon := state.viewport.centerLon
  }

/-- Stop dragging -/
def stopDrag (state : MapState) : MapState :=
  { state with isDragging := false }

/-- Reset to initial view (for Home key) -/
def resetToInitial (state : MapState) : MapState :=
  { state with
    viewport := { state.viewport with
      centerLat := state.initialLat
      centerLon := state.initialLon
      zoom := state.initialZoom
    }
    targetZoom := state.initialZoom
    displayZoom := intToFloat state.initialZoom
    isAnimatingZoom := false
  }

end MapState

end Worldmap

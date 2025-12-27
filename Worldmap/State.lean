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

end MapState

end Worldmap

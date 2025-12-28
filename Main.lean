/-
  Worldmap - Tile-based map viewer with Web Mercator projection

  Features:
  - Pan: Click and drag to pan the map
  - Zoom: Mouse wheel to zoom (zooms toward cursor position)
  - Async tile loading with disk caching
  - Exponential backoff retry logic
  - Parent tile fallback rendering
-/
import Afferent
import Worldmap
import Wisp

open Afferent Afferent.FFI Worldmap

/-- Map demo state maintained across frames -/
structure MapDemoState where
  mapState : MapState
  markerLayer : MarkerLayer
  initialized : Bool := false
  httpInitialized : Bool := false

/-- Initialize map demo state centered on San Francisco -/
def MapDemoState.create (screenWidth screenHeight : Float) : IO MapDemoState := do
  -- Initialize HTTP (curl global state via Wisp)
  Wisp.FFI.globalInit

  -- Disk cache config - use a reasonable cache size and path
  let diskConfig : Worldmap.TileDiskCacheConfig := {
    cacheDir := "./tile_cache"
    tilesetName := "carto-dark-2x"
    maxSizeBytes := Worldmap.defaultDiskCacheSizeBytes
  }

  -- Initialize map state centered on San Francisco
  let mapState ← MapState.init
    37.7749  -- latitude
    (-122.4194)  -- longitude
    12  -- initial zoom level
    screenWidth.toInt64.toInt
    screenHeight.toInt64.toInt
    diskConfig

  -- Create demo markers around San Francisco
  let mut markers := MarkerLayer.empty
  -- Golden Gate Bridge
  markers := (markers.addMarker 37.8199 (-122.4783) (some "Golden Gate Bridge") MarkerColor.red 14.0).1
  -- Alcatraz Island
  markers := (markers.addMarker 37.8267 (-122.4230) (some "Alcatraz") MarkerColor.orange 12.0).1
  -- Fisherman's Wharf
  markers := (markers.addMarker 37.8080 (-122.4177) (some "Fisherman's Wharf") MarkerColor.blue 12.0).1
  -- Coit Tower
  markers := (markers.addMarker 37.8024 (-122.4058) (some "Coit Tower") MarkerColor.green 12.0).1
  -- Union Square
  markers := (markers.addMarker 37.7879 (-122.4074) (some "Union Square") MarkerColor.purple 12.0).1
  -- AT&T Park (Oracle Park)
  markers := (markers.addMarker 37.7786 (-122.3893) (some "Oracle Park") MarkerColor.yellow 12.0).1
  -- Twin Peaks
  markers := (markers.addMarker 37.7544 (-122.4477) (some "Twin Peaks") MarkerColor.green 12.0).1
  -- Golden Gate Park
  markers := (markers.addMarker 37.7694 (-122.4862) (some "Golden Gate Park") MarkerColor.green 14.0).1

  pure { mapState, markerLayer := markers, initialized := true, httpInitialized := true }

/-- Clean up map demo resources -/
def MapDemoState.cleanup (state : MapDemoState) : IO Unit := do
  -- Match heavenly-host behavior: explicitly release GPU textures.
  for tex in state.mapState.cache.getLoadedTextures do
    Afferent.FFI.Texture.destroy tex
  if state.httpInitialized then
    Wisp.FFI.globalCleanup

/-- Update map demo state for one frame -/
def MapDemoState.update (state : MapDemoState) (window : Window) : IO MapDemoState := do
  -- Get current window size and update viewport (supports window resize)
  let (w, h) ← Window.getSize window
  let mapState := state.mapState.updateScreenSize w.toNat h.toNat

  -- Handle input (pan and zoom)
  let mapState ← handleInput window mapState

  -- Update zoom animation
  let mapState := updateZoomAnimation mapState

  -- Cancel tasks for tiles no longer needed
  cancelStaleTasks mapState

  -- Update tile cache (spawn fetches, process results, handle retries)
  let mapState ← updateTileCache mapState

  pure { state with mapState }

/-- Render the map -/
def MapDemoState.render (state : MapDemoState) (renderer : Renderer) : IO Unit := do
  Worldmap.render renderer state.mapState

/-- Get current map info for overlay display -/
def MapDemoState.getInfo (state : MapDemoState) : String :=
  let vp := state.mapState.viewport
  let lat := vp.centerLat
  let lon := vp.centerLon
  let vpZoom := vp.zoom  -- viewport.zoom (used for tile fetching)
  let targetZoom := state.mapState.targetZoom
  let displayZoom := state.mapState.displayZoom
  let cacheCount := state.mapState.cache.tiles.size
  s!"Map: lat={lat} lon={lon} vpZoom={vpZoom} target={targetZoom} display={displayZoom} tiles={cacheCount}"

/-- Main entry point -/
def main : IO Unit := do
  IO.println "Worldmap - Tile-based Map Viewer"
  IO.println "================================"
  IO.println "Controls:"
  IO.println "  - Drag to pan"
  IO.println "  - Scroll wheel to zoom"
  IO.println "  - Close window to exit"
  IO.println ""

  -- Get screen scale
  let screenScale ← FFI.getScreenScale

  -- Dimensions
  let baseWidth : Float := 1280.0
  let baseHeight : Float := 720.0
  let physWidth := (baseWidth * screenScale).toUInt32
  let physHeight := (baseHeight * screenScale).toUInt32

  -- Create window and renderer
  let canvas ← Canvas.create physWidth physHeight "Worldmap - Tile Viewer"

  -- Load font for overlay
  let font ← Afferent.Font.load "/System/Library/Fonts/Monaco.ttf" (14 * screenScale).toUInt32

  -- Initialize map
  let physWidthF := baseWidth * screenScale
  let physHeightF := baseHeight * screenScale
  let mut state ← MapDemoState.create physWidthF physHeightF

  -- Main loop
  let mut c := canvas
  while !(← c.shouldClose) do
    c.pollEvents

    let ok ← c.beginFrame Color.darkGray
    if ok then
      -- Update map
      state ← state.update c.ctx.window

      -- Render map
      state.render c.ctx.renderer

      -- Render markers
      c ← CanvasM.run' (c.resetTransform) do
        let visibleMarkers := state.markerLayer.markersInView state.mapState.viewport
        for marker in visibleMarkers do
          let (sx, sy) := MarkerLayer.markerScreenPos marker state.mapState.viewport
          -- Draw marker circle
          let color := Color.rgba marker.color.r marker.color.g marker.color.b marker.color.a
          CanvasM.setFillColor color
          CanvasM.fillCircle ⟨sx, sy⟩ marker.size

      -- Get overlay info
      let (_, h) ← c.ctx.getCurrentSize
      let info := state.getInfo
      let (scaleLabel, scalePixels) := getScaleBarInfo state.mapState 150.0

      -- Render overlay
      c ← CanvasM.run' (c.resetTransform) do
        -- Top info bar
        CanvasM.setFillColor (Color.hsva 0.0 0.0 0.0 0.6)
        CanvasM.fillRectXYWH (10 * screenScale) (10 * screenScale) (500 * screenScale) (25 * screenScale)
        CanvasM.setFillColor Color.white
        CanvasM.fillTextXY info (20 * screenScale) (27 * screenScale) font

        -- Scale bar (bottom left)
        let scaleY := h - 30 * screenScale
        let scaleX := 20 * screenScale
        -- Background
        CanvasM.setFillColor (Color.hsva 0.0 0.0 0.0 0.6)
        CanvasM.fillRectXYWH (scaleX - 5 * screenScale) (scaleY - 20 * screenScale) (scalePixels * screenScale + 10 * screenScale) (35 * screenScale)
        -- Scale bar line
        CanvasM.setFillColor Color.white
        CanvasM.fillRectXYWH scaleX scaleY (scalePixels * screenScale) (4 * screenScale)
        -- End caps
        CanvasM.fillRectXYWH scaleX (scaleY - 6 * screenScale) (2 * screenScale) (16 * screenScale)
        CanvasM.fillRectXYWH (scaleX + scalePixels * screenScale - 2 * screenScale) (scaleY - 6 * screenScale) (2 * screenScale) (16 * screenScale)
        -- Label
        CanvasM.fillTextXY scaleLabel (scaleX + 4 * screenScale) (scaleY - 6 * screenScale) font

      c ← c.endFrame

  -- Cleanup
  IO.println "Cleaning up..."
  state.cleanup
  font.destroy
  canvas.destroy
  IO.println "Done!"

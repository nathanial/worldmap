/-
  Map Overlay Rendering
  Renders UI elements on top of the map (coordinates, scale bar, loading indicator)
-/
import Worldmap.State
import Worldmap.Utils

namespace Worldmap

/-- Format a latitude value with direction (N/S) -/
def formatLatitude (lat : Float) (decimals : Nat := 5) : String :=
  let absLat := if lat < 0.0 then -lat else lat
  let dir := if lat >= 0.0 then "N" else "S"
  let str := toString absLat
  -- Truncate to desired decimals
  let parts := str.splitOn "."
  let formatted := match parts with
    | [whole] => whole ++ ".00000"
    | [whole, frac] =>
      let truncFrac := frac.take decimals
      let padded := truncFrac ++ String.ofList (List.replicate (decimals - truncFrac.length) '0')
      whole ++ "." ++ padded
    | _ => str
  formatted ++ "° " ++ dir

/-- Format a longitude value with direction (E/W) -/
def formatLongitude (lon : Float) (decimals : Nat := 5) : String :=
  let absLon := if lon < 0.0 then -lon else lon
  let dir := if lon >= 0.0 then "E" else "W"
  let str := toString absLon
  -- Truncate to desired decimals
  let parts := str.splitOn "."
  let formatted := match parts with
    | [whole] => whole ++ ".00000"
    | [whole, frac] =>
      let truncFrac := frac.take decimals
      let padded := truncFrac ++ String.ofList (List.replicate (decimals - truncFrac.length) '0')
      whole ++ "." ++ padded
    | _ => str
  formatted ++ "° " ++ dir

/-- Format coordinates as a single string -/
def formatCoordinates (lat lon : Float) (decimals : Nat := 5) : String :=
  formatLatitude lat decimals ++ ", " ++ formatLongitude lon decimals

/-- Get formatted cursor coordinates from state -/
def getCursorCoordinates (state : MapState) : String :=
  formatCoordinates state.cursorLat state.cursorLon

/-- Get formatted center coordinates from state -/
def getCenterCoordinates (state : MapState) : String :=
  formatCoordinates state.viewport.centerLat state.viewport.centerLon

/-- Get current zoom level as string -/
def getZoomString (state : MapState) : String :=
  "Zoom: " ++ toString state.viewport.zoom

-- ============================================================================
-- Scale Bar Calculations
-- ============================================================================

/-- Earth's equatorial radius in meters -/
def earthRadius : Float := 6378137.0

/-- Calculate meters per pixel at a given latitude and zoom level -/
def metersPerPixel (lat : Float) (zoom : Int) (tileSize : Int := 512) : Float :=
  let latRad := lat * pi / 180.0
  let circumference := 2.0 * pi * earthRadius
  let tilesAtZoom := Float.pow 2.0 (intToFloat zoom)
  let metersPerTile := circumference * Float.cos latRad / tilesAtZoom
  metersPerTile / intToFloat tileSize

/-- Nice scale bar distances in meters -/
def niceDistances : Array Float := #[
  1, 2, 5, 10, 20, 50, 100, 200, 500,
  1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000,
  1000000, 2000000, 5000000
]

/-- Find the best scale bar distance for a given max pixel width -/
def findBestScaleDistance (metersPerPx : Float) (maxPixels : Float := 150.0) : Float × Float :=
  let maxMeters := metersPerPx * maxPixels
  -- Find largest nice distance that fits
  let bestDistance := niceDistances.foldl (fun best d =>
    if d <= maxMeters then d else best
  ) 1.0
  let pixels := bestDistance / metersPerPx
  (bestDistance, pixels)

/-- Format distance for display -/
def formatDistance (meters : Float) : String :=
  if meters >= 1000.0 then
    let km := meters / 1000.0
    if km == Float.floor km then
      toString (Float.floor km).toUInt64 ++ " km"
    else
      toString km ++ " km"
  else
    toString meters.toUInt64 ++ " m"

/-- Get scale bar info: (label, pixelWidth) -/
def getScaleBarInfo (state : MapState) (maxPixels : Float := 150.0) : String × Float :=
  let mpp := metersPerPixel state.viewport.centerLat state.viewport.zoom state.viewport.tileSize
  let (meters, pixels) := findBestScaleDistance mpp maxPixels
  (formatDistance meters, pixels)

-- ============================================================================
-- Tile Loading Status
-- ============================================================================

/-- Get tile loading status: (loaded, pending, failed) -/
def getTileStatus (state : MapState) : Nat × Nat × Nat :=
  let (gpu, ram, other) := state.cache.stateCounts
  (ram + gpu, other, 0)  -- other includes pending and failed

/-- Format tile loading status -/
def formatTileStatus (state : MapState) : String :=
  let (loaded, pending, _) := getTileStatus state
  if pending > 0 then
    s!"Loading: {pending} tiles"
  else
    s!"Tiles: {loaded}"

end Worldmap

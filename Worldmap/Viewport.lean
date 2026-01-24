/-
  Map Viewport - Screen to geographic coordinate transforms
  Extracted from Afferent to Worldmap
-/
import Std.Data.HashSet
import Worldmap.TileCoord

namespace Worldmap

/-- Map viewport state -/
structure MapViewport where
  centerLat : Float
  centerLon : Float
  zoom : Int             -- 0-19
  screenWidth : Int
  screenHeight : Int
  tileSize : Int := 512  -- Rendering in physical pixels; @2x tiles are 512x512
  deriving Repr, Inhabited

namespace MapViewport

private def floatFloorInt (v : Float) : Int :=
  if v >= 0.0 then
    natToInt v.floor.toUInt64.toNat
  else
    -natToInt ((-v).ceil.toUInt64.toNat)

private def floatCeilInt (v : Float) : Int :=
  if v >= 0.0 then
    natToInt v.ceil.toUInt64.toNat
  else
    -natToInt ((-v).floor.toUInt64.toNat)

/-- Calculate fractional tile position for the center -/
def centerTilePos (vp : MapViewport) : (Float × Float) :=
  let n := Float.pow 2.0 (intToFloat vp.zoom)
  let centerX := (vp.centerLon + 180.0) / 360.0 * n
  let latRad := vp.centerLat * pi / 180.0
  let centerY := (1.0 - Float.log (Float.tan latRad + 1.0 / Float.cos latRad) / pi) / 2.0 * n
  (centerX, centerY)

/-- Calculate visible tiles plus a configurable buffer zone. -/
def visibleTilesWithBuffer (vp : MapViewport) (buffer : Int) : List TileCoord :=
  let (centerX, centerY) := vp.centerTilePos
  let halfWidth := (intToFloat vp.screenWidth) / (intToFloat vp.tileSize) / 2.0
  let halfHeight := (intToFloat vp.screenHeight) / (intToFloat vp.tileSize) / 2.0
  let bufferTiles := intToFloat buffer
  let left := centerX - halfWidth - bufferTiles
  let right := centerX + halfWidth + bufferTiles
  let top := centerY - halfHeight - bufferTiles
  let bottom := centerY + halfHeight + bufferTiles
  let minX := floatFloorInt left
  let maxX := floatCeilInt right - 1
  let minYRaw := floatFloorInt top
  let maxYRaw := floatCeilInt bottom - 1
  let maxTile := tilesAtZoom vp.zoom - 1
  let minY := intMax 0 minYRaw
  let maxY := intMin maxTile maxYRaw
  if minY > maxY then
    []
  else
    let spanX := maxX - minX + 1
    if spanX <= 0 then
      []
    else
      let spanXNat := spanX.toNat
      let spanYNat := (maxY - minY + 1).toNat
      let result := Id.run do
        let mut tiles : List TileCoord := []
        for dy in [0:spanYNat] do
          let y := minY + natToInt dy
          for dx in [0:spanXNat] do
            let x := minX + natToInt dx
            let x := x % (maxTile + 1)
            let x := if x < 0 then x + maxTile + 1 else x
            tiles := { x := x, y := y, z := vp.zoom } :: tiles
        return tiles
      result

/-- Calculate which tiles are visible in the current viewport -/
def visibleTiles (vp : MapViewport) : List TileCoord :=
  vp.visibleTilesWithBuffer 0

/-- Create a HashSet of tiles to keep for efficient lookup -/
def visibleTileSet (vp : MapViewport) (buffer : Int) : Std.HashSet TileCoord :=
  let tiles := vp.visibleTilesWithBuffer buffer
  tiles.foldl (fun s t => s.insert t) {}

/-- Create a HashSet including tiles at adjacent zoom levels for fallback rendering.
    Includes parent/grandparent tiles (for zoom-in) and child tiles (for zoom-out). -/
def visibleTileSetWithFallbacks (vp : MapViewport) (buffer : Int) : Std.HashSet TileCoord :=
  let baseTiles := vp.visibleTilesWithBuffer buffer
  -- Build base set
  let baseSet : Std.HashSet TileCoord := baseTiles.foldl (fun s t => s.insert t) {}
  -- Add parent tiles (for zoom-in fallback)
  let withParents := if vp.zoom <= 0 then baseSet
    else baseTiles.foldl (fun s t => s.insert t.parentTile) baseSet
  -- Add grandparent tiles (for 2-level zoom-in fallback)
  let withGrandparents := if vp.zoom <= 1 then withParents
    else baseTiles.foldl (fun s t => s.insert t.parentTile.parentTile) withParents
  -- Add child tiles (for zoom-out fallback) - 4 children per visible tile
  if vp.zoom >= 19 then withGrandparents
  else baseTiles.foldl (fun s t =>
    let children := t.childTiles
    s.insert children[0]! |>.insert children[1]! |>.insert children[2]! |>.insert children[3]!
  ) withGrandparents

/-- Calculate screen position for a tile -/
def tileScreenPos (vp : MapViewport) (tile : TileCoord) : (Int × Int) :=
  let (centerX, centerY) := vp.centerTilePos
  let offsetX := ((intToFloat tile.x) - centerX) * (intToFloat vp.tileSize) + (intToFloat vp.screenWidth) / 2.0
  let offsetY := ((intToFloat tile.y) - centerY) * (intToFloat vp.tileSize) + (intToFloat vp.screenHeight) / 2.0
  -- Handle negative floats properly for conversion
  let xInt := if offsetX >= 0.0 then natToInt offsetX.toUInt64.toNat else -(natToInt ((-offsetX).toUInt64.toNat))
  let yInt := if offsetY >= 0.0 then natToInt offsetY.toUInt64.toNat else -(natToInt ((-offsetY).toUInt64.toNat))
  (xInt, yInt)

/-- Convert screen delta to longitude/latitude delta -/
def pixelsToDegrees (vp : MapViewport) (dx dy : Float) : (Float × Float) :=
  let n := Float.pow 2.0 (intToFloat vp.zoom)
  let degreesPerPixelX := 360.0 / (n * (intToFloat vp.tileSize))
  let latRad := vp.centerLat * pi / 180.0
  let degreesPerPixelY := 360.0 * Float.cos latRad / (n * (intToFloat vp.tileSize))
  (dx * degreesPerPixelX, dy * degreesPerPixelY)

end MapViewport

end Worldmap

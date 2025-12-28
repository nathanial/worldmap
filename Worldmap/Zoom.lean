/-
  Zoom-to-Point (Zoom to Cursor)

  This module provides pure functions for zoom-to-point operations.
  When zooming, the geographic point under the cursor stays fixed.

  The key formula: newCenterTile = oldCenterTile * k + cursorOffset * (k - 1)
  where k = 2^(newZoom - oldZoom) is the zoom ratio.

  Extracted from Afferent to Worldmap
-/

import Worldmap.Viewport

namespace Worldmap.Zoom

open Worldmap

/-- Convert screen coordinates to fractional tile position -/
def screenToTile (vp : MapViewport) (sx sy : Float) : (Float × Float) :=
  let (centerTileX, centerTileY) := vp.centerTilePos
  let cx := (intToFloat vp.screenWidth) / 2.0
  let cy := (intToFloat vp.screenHeight) / 2.0
  (centerTileX + (sx - cx) / (intToFloat vp.tileSize),
   centerTileY + (sy - cy) / (intToFloat vp.tileSize))

/-- Convert fractional tile position to geographic coordinates (inverse Mercator).
    Returns (latitude, longitude). -/
def tileToGeo (tileX tileY : Float) (zoom : Int) : (Float × Float) :=
  let n := Float.pow 2.0 (intToFloat zoom)
  let lon := tileX / n * 360.0 - 180.0
  let latRad := Float.atan (Float.sinh (pi * (1.0 - 2.0 * tileY / n)))
  let lat := latRad * 180.0 / pi
  (lat, lon)

/-- Convert screen coordinates to geographic coordinates.
    Returns (latitude, longitude). -/
def screenToGeo (vp : MapViewport) (sx sy : Float) : (Float × Float) :=
  let (tileX, tileY) := screenToTile vp sx sy
  tileToGeo tileX tileY vp.zoom

/-- Convert geographic coordinates to fractional tile position (Mercator projection).
    Returns (tileX, tileY). -/
def geoToTile (lat lon : Float) (zoom : Int) : (Float × Float) :=
  let n := Float.pow 2.0 (intToFloat zoom)
  let tileX := (lon + 180.0) / 360.0 * n
  let latRad := lat * pi / 180.0
  let tileY := (1.0 - Float.log (Float.tan latRad + 1.0 / Float.cos latRad) / pi) / 2.0 * n
  (tileX, tileY)

/-- Convert fractional tile position to screen coordinates.
    Returns (screenX, screenY). -/
def tileToScreen (vp : MapViewport) (tileX tileY : Float) : (Float × Float) :=
  let (centerTileX, centerTileY) := vp.centerTilePos
  let cx := (intToFloat vp.screenWidth) / 2.0
  let cy := (intToFloat vp.screenHeight) / 2.0
  let sx := cx + (tileX - centerTileX) * (intToFloat vp.tileSize)
  let sy := cy + (tileY - centerTileY) * (intToFloat vp.tileSize)
  (sx, sy)

/-- Convert geographic coordinates to screen coordinates.
    Returns (screenX, screenY). -/
def geoToScreen (vp : MapViewport) (lat lon : Float) : (Float × Float) :=
  let (tileX, tileY) := geoToTile lat lon vp.zoom
  tileToScreen vp tileX tileY

/-- Compute new center after zooming at cursor position.
    Returns (newLat, newLon).

    The formula ensures that the cursor's screen position maps to the same
    geographic point before and after the zoom (the fixed point property). -/
def zoomToPointCenter (vp : MapViewport) (cursorX cursorY : Float)
                       (newZoom : Int) : (Float × Float) :=
  let oldN := Float.pow 2.0 (intToFloat vp.zoom)
  let newN := Float.pow 2.0 (intToFloat newZoom)
  let k := newN / oldN  -- zoom ratio

  -- Screen center
  let cx := (intToFloat vp.screenWidth) / 2.0
  let cy := (intToFloat vp.screenHeight) / 2.0

  -- Offset from screen center to cursor in tile units (at old zoom)
  let dxTile := (cursorX - cx) / (intToFloat vp.tileSize)
  let dyTile := (cursorY - cy) / (intToFloat vp.tileSize)

  -- Old center in tile coords
  let (oldCenterTileX, oldCenterTileY) := vp.centerTilePos

  -- New center in tile coords (at NEW zoom level)
  -- This formula ensures: cursorTileX * k - newCenterTileX = dxTile
  -- i.e., the cursor's screen offset from center stays the same
  let newCenterTileX := oldCenterTileX * k + dxTile * (k - 1.0)
  let newCenterTileY := oldCenterTileY * k + dyTile * (k - 1.0)

  -- Convert new center tile coords to geographic
  tileToGeo newCenterTileX newCenterTileY newZoom

/-- Create new viewport after zoom-to-point.
    The geographic point under the cursor remains fixed after zooming. -/
def zoomToPoint (vp : MapViewport) (cursorX cursorY : Float)
                (newZoom : Int) : MapViewport :=
  let clampedZoom := clampZoom newZoom
  let (newLat, newLon) := zoomToPointCenter vp cursorX cursorY clampedZoom
  { vp with
    centerLat := clampLatitude newLat
    centerLon := wrapLongitude newLon
    zoom := clampedZoom
  }

/-- Convert lat/lon to fractional tile position at fractional zoom level -/
def geoToTileFrac (lat lon : Float) (zoom : Float) : (Float × Float) :=
  let n := Float.pow 2.0 zoom
  let tileX := (lon + 180.0) / 360.0 * n
  let latRad := lat * pi / 180.0
  let tileY := (1.0 - Float.log (Float.tan latRad + 1.0 / Float.cos latRad) / pi) / 2.0 * n
  (tileX, tileY)

/-- Convert geographic coordinates to screen coordinates with fractional zoom.
    Returns (screenX, screenY). -/
def geoToScreenFrac (vp : MapViewport) (lat lon : Float) (displayZoom : Float) : (Float × Float) :=
  -- Convert lat/lon to tile position at fractional zoom
  let (tileX, tileY) := geoToTileFrac lat lon displayZoom
  -- Compute center tile position at fractional zoom
  let n := Float.pow 2.0 displayZoom
  let centerTileX := (vp.centerLon + 180.0) / 360.0 * n
  let latRad := vp.centerLat * pi / 180.0
  let centerTileY := (1.0 - Float.log (Float.tan latRad + 1.0 / Float.cos latRad) / pi) / 2.0 * n
  -- Convert to screen coordinates
  let cx := (intToFloat vp.screenWidth) / 2.0
  let cy := (intToFloat vp.screenHeight) / 2.0
  let sx := cx + (tileX - centerTileX) * (intToFloat vp.tileSize)
  let sy := cy + (tileY - centerTileY) * (intToFloat vp.tileSize)
  (sx, sy)

/-- Convert fractional tile position to lat/lon at fractional zoom level -/
def tileToGeoFrac (tileX tileY : Float) (zoom : Float) : (Float × Float) :=
  let n := Float.pow 2.0 zoom
  let lon := tileX / n * 360.0 - 180.0
  let latRad := Float.atan (Float.sinh (pi * (1.0 - 2.0 * tileY / n)))
  let lat := latRad * 180.0 / pi
  (lat, lon)

/-- Compute center position to keep anchor point fixed at anchor screen position.
    Given an anchor geographic point and where it should appear on screen,
    computes the map center that achieves this at the given (fractional) zoom. -/
def centerForAnchor (anchorLat anchorLon : Float)
    (anchorScreenX anchorScreenY : Float)
    (screenWidth screenHeight tileSize : Int)
    (displayZoom : Float) : (Float × Float) :=
  -- Convert anchor point to tile coordinates at current display zoom
  let (anchorTileX, anchorTileY) := geoToTileFrac anchorLat anchorLon displayZoom
  -- Compute offset from screen center to anchor in tile units
  let cx := (intToFloat screenWidth) / 2.0
  let cy := (intToFloat screenHeight) / 2.0
  let dxTile := (anchorScreenX - cx) / (intToFloat tileSize)
  let dyTile := (anchorScreenY - cy) / (intToFloat tileSize)
  -- Center tile position: anchor - offset
  let centerTileX := anchorTileX - dxTile
  let centerTileY := anchorTileY - dyTile
  -- Convert back to geographic coordinates
  tileToGeoFrac centerTileX centerTileY displayZoom

end Worldmap.Zoom

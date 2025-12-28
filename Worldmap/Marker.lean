/-
  Marker/Point Layer for Map
  Supports placing markers at geographic coordinates with labels and custom styling.
-/
import Worldmap.Viewport
import Worldmap.Zoom

namespace Worldmap

/-- Marker color (simple RGBA) -/
structure MarkerColor where
  r : Float := 1.0
  g : Float := 0.0
  b : Float := 0.0
  a : Float := 1.0
  deriving Repr, Inhabited, BEq

namespace MarkerColor

def red : MarkerColor := { r := 1.0, g := 0.0, b := 0.0 }
def green : MarkerColor := { r := 0.0, g := 0.8, b := 0.0 }
def blue : MarkerColor := { r := 0.0, g := 0.4, b := 1.0 }
def yellow : MarkerColor := { r := 1.0, g := 0.9, b := 0.0 }
def orange : MarkerColor := { r := 1.0, g := 0.5, b := 0.0 }
def purple : MarkerColor := { r := 0.6, g := 0.2, b := 0.8 }
def white : MarkerColor := { r := 1.0, g := 1.0, b := 1.0 }
def black : MarkerColor := { r := 0.0, g := 0.0, b := 0.0 }

def withAlpha (c : MarkerColor) (a : Float) : MarkerColor :=
  { c with a := a }

end MarkerColor

/-- Unique identifier for a marker -/
abbrev MarkerId := Nat

/-- A marker on the map -/
structure Marker where
  id : MarkerId
  lat : Float
  lon : Float
  label : Option String := none
  color : MarkerColor := MarkerColor.red
  size : Float := 12.0
  deriving Repr, Inhabited, BEq

namespace Marker

/-- Create a simple marker with just coordinates -/
def simple (id : MarkerId) (lat lon : Float) : Marker :=
  { id := id, lat := lat, lon := lon }

/-- Create a labeled marker -/
def labeled (id : MarkerId) (lat lon : Float) (label : String) : Marker :=
  { id := id, lat := lat, lon := lon, label := some label }

/-- Create a marker with custom color -/
def colored (id : MarkerId) (lat lon : Float) (color : MarkerColor) : Marker :=
  { id := id, lat := lat, lon := lon, color := color }

/-- Create a fully customized marker -/
def custom (id : MarkerId) (lat lon : Float) (label : Option String)
    (color : MarkerColor) (size : Float) : Marker :=
  { id := id, lat := lat, lon := lon, label := label, color := color, size := size }

end Marker

/-- Collection of markers as a layer -/
structure MarkerLayer where
  markers : Array Marker := #[]
  visible : Bool := true
  nextId : MarkerId := 0
  deriving Repr, Inhabited

namespace MarkerLayer

/-- Create an empty marker layer -/
def empty : MarkerLayer := {}

/-- Add a marker at coordinates, returns (new layer, marker id) -/
def addMarker (layer : MarkerLayer) (lat lon : Float)
    (label : Option String := none) (color : MarkerColor := MarkerColor.red)
    (size : Float := 12.0) : MarkerLayer × MarkerId :=
  let marker := Marker.custom layer.nextId lat lon label color size
  let newLayer := { layer with
    markers := layer.markers.push marker
    nextId := layer.nextId + 1
  }
  (newLayer, marker.id)

/-- Add an existing marker (updates its id) -/
def addExisting (layer : MarkerLayer) (marker : Marker) : MarkerLayer × MarkerId :=
  let newMarker := { marker with id := layer.nextId }
  let newLayer := { layer with
    markers := layer.markers.push newMarker
    nextId := layer.nextId + 1
  }
  (newLayer, newMarker.id)

/-- Remove a marker by id -/
def removeMarker (layer : MarkerLayer) (id : MarkerId) : MarkerLayer :=
  { layer with markers := layer.markers.filter (·.id != id) }

/-- Clear all markers -/
def clearMarkers (layer : MarkerLayer) : MarkerLayer :=
  { layer with markers := #[], nextId := 0 }

/-- Get marker by id -/
def getMarker (layer : MarkerLayer) (id : MarkerId) : Option Marker :=
  layer.markers.find? (·.id == id)

/-- Update a marker by id -/
def updateMarker (layer : MarkerLayer) (id : MarkerId) (f : Marker → Marker) : MarkerLayer :=
  { layer with
    markers := layer.markers.map fun m =>
      if m.id == id then f m else m
  }

/-- Set marker label -/
def setLabel (layer : MarkerLayer) (id : MarkerId) (label : Option String) : MarkerLayer :=
  layer.updateMarker id (fun m => { m with label := label })

/-- Set marker color -/
def setColor (layer : MarkerLayer) (id : MarkerId) (color : MarkerColor) : MarkerLayer :=
  layer.updateMarker id (fun m => { m with color := color })

/-- Set marker size -/
def setSize (layer : MarkerLayer) (id : MarkerId) (size : Float) : MarkerLayer :=
  layer.updateMarker id (fun m => { m with size := size })

/-- Move marker to new coordinates -/
def moveMarker (layer : MarkerLayer) (id : MarkerId) (lat lon : Float) : MarkerLayer :=
  layer.updateMarker id (fun m => { m with lat := lat, lon := lon })

/-- Number of markers in layer -/
def count (layer : MarkerLayer) : Nat :=
  layer.markers.size

/-- Toggle layer visibility -/
def toggleVisibility (layer : MarkerLayer) : MarkerLayer :=
  { layer with visible := !layer.visible }

/-- Set layer visibility -/
def setVisibility (layer : MarkerLayer) (visible : Bool) : MarkerLayer :=
  { layer with visible := visible }

-- ============================================================================
-- Viewport Culling
-- ============================================================================

/-- Check if a marker is within the viewport bounds -/
def markerInView (marker : Marker) (viewport : MapViewport) : Bool :=
  -- Get viewport corners in geographic coordinates
  let halfWidth := intToFloat viewport.screenWidth / 2.0
  let halfHeight := intToFloat viewport.screenHeight / 2.0
  let (_, dLat) := viewport.pixelsToDegrees 0.0 halfHeight
  let (dLon, _) := viewport.pixelsToDegrees halfWidth 0.0

  let minLat := viewport.centerLat - dLat
  let maxLat := viewport.centerLat + dLat
  let minLon := viewport.centerLon - dLon
  let maxLon := viewport.centerLon + dLon

  marker.lat >= minLat && marker.lat <= maxLat &&
  marker.lon >= minLon && marker.lon <= maxLon

/-- Get all markers visible in the current viewport -/
def markersInView (layer : MarkerLayer) (viewport : MapViewport) : Array Marker :=
  if !layer.visible then #[]
  else layer.markers.filter (markerInView · viewport)

-- ============================================================================
-- Hit Testing
-- ============================================================================

/-- Convert marker geographic position to screen position -/
def markerScreenPos (marker : Marker) (viewport : MapViewport) : Float × Float :=
  Zoom.geoToScreen viewport marker.lat marker.lon

/-- Convert marker geographic position to screen position with fractional zoom -/
def markerScreenPosFrac (marker : Marker) (viewport : MapViewport) (displayZoom : Float) : Float × Float :=
  Zoom.geoToScreenFrac viewport marker.lat marker.lon displayZoom

/-- Check if a screen point hits a marker -/
def hitTestMarker (marker : Marker) (viewport : MapViewport)
    (screenX screenY : Float) : Bool :=
  let (mx, my) := markerScreenPos marker viewport
  let dx := screenX - mx
  let dy := screenY - my
  let dist := Float.sqrt (dx * dx + dy * dy)
  dist <= marker.size

/-- Find the topmost marker at screen position (returns id) -/
def hitTest (layer : MarkerLayer) (viewport : MapViewport)
    (screenX screenY : Float) : Option MarkerId :=
  if !layer.visible then none
  else
    -- Check markers in reverse order (last added is on top)
    let visibleMarkers := layer.markersInView viewport
    visibleMarkers.foldr (fun m acc =>
      match acc with
      | some _ => acc  -- Already found one
      | none => if hitTestMarker m viewport screenX screenY then some m.id else none
    ) none

/-- Find all markers at screen position -/
def hitTestAll (layer : MarkerLayer) (viewport : MapViewport)
    (screenX screenY : Float) : Array MarkerId :=
  if !layer.visible then #[]
  else
    layer.markersInView viewport
      |>.filter (hitTestMarker · viewport screenX screenY)
      |>.map (·.id)

end MarkerLayer

end Worldmap

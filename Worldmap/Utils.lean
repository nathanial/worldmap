/-
  Shared utility functions and constants for Worldmap
-/
namespace Worldmap

/-- Pi constant -/
def pi : Float := 3.14159265358979323846

/-- Maximum latitude for Web Mercator projection (degrees) -/
def maxMercatorLatitude : Float := 85.0

/-- Minimum zoom level -/
def minZoomLevel : Int := 0

/-- Maximum zoom level -/
def maxZoomLevel : Int := 19

/-- Default maximum number of PNG images to keep in RAM cache -/
def defaultMaxCachedImages : Nat := 1500

/-- Default disk cache size in bytes (100 MB) -/
def defaultDiskCacheSizeBytes : Nat := 100 * 1024 * 1024

/-- Default tile size for @2x retina tiles -/
def defaultTileSize : Int := 512

-- ============================================================================
-- Utility Functions (must come before MapBounds)
-- ============================================================================

/-- Convert Int to Float -/
@[inline] def intToFloat (n : Int) : Float := Float.ofInt n

/-- Convert Nat to Int -/
@[inline] def natToInt (n : Nat) : Int := n

/-- Max of two integers -/
@[inline] def intMax (a b : Int) : Int := if a > b then a else b

/-- Min of two integers -/
@[inline] def intMin (a b : Int) : Int := if a < b then a else b

/-- Max of two floats -/
@[inline] def floatMax (a b : Float) : Float := if a > b then a else b

/-- Min of two floats -/
@[inline] def floatMin (a b : Float) : Float := if a < b then a else b

/-- Clamp float to range [min, max] -/
@[inline] def floatClamp (value min max : Float) : Float :=
  floatMin max (floatMax min value)

/-- Clamp integer to range [min, max] -/
@[inline] def intClamp (value min max : Int) : Int :=
  intMin max (intMax min value)

/-- Clamp latitude to valid Mercator range -/
@[inline] def clampLatitude (lat : Float) : Float :=
  floatClamp lat (-maxMercatorLatitude) maxMercatorLatitude

/-- Wrap longitude to [-180, 180] range -/
@[inline] def wrapLongitude (lon : Float) : Float :=
  if lon > 180.0 then lon - 360.0
  else if lon < -180.0 then lon + 360.0
  else lon

/-- Clamp zoom level to valid range [0, 19] -/
@[inline] def clampZoom (z : Int) : Int :=
  intClamp z minZoomLevel maxZoomLevel

-- ============================================================================
-- Zoom Animation Configuration
-- ============================================================================

/-- Easing function type for zoom animations -/
inductive EasingType where
  | linear       -- No easing, constant speed
  | easeOut      -- Decelerate toward end
  | easeInOut    -- Accelerate then decelerate
  deriving Repr, BEq, Inhabited

namespace EasingType

/-- Apply easing function to a value t in [0, 1] -/
def apply (easing : EasingType) (t : Float) : Float :=
  match easing with
  | .linear => t
  | .easeOut => 1.0 - (1.0 - t) * (1.0 - t)  -- Quadratic ease out
  | .easeInOut =>
    if t < 0.5 then
      2.0 * t * t
    else
      1.0 - ((-2.0 * t + 2.0) * (-2.0 * t + 2.0)) / 2.0

end EasingType

/-- Configuration for zoom animation behavior -/
structure ZoomAnimationConfig where
  /-- Lerp factor per frame (higher = faster animation) -/
  lerpFactor : Float := 0.15
  /-- Threshold for snapping to target zoom -/
  snapThreshold : Float := 0.01
  /-- Easing function for zoom animation -/
  easing : EasingType := .linear
  deriving Repr, Inhabited

/-- Default zoom animation configuration -/
def defaultZoomAnimationConfig : ZoomAnimationConfig := {}

/-- Fast zoom animation (snappier feel) -/
def fastZoomAnimationConfig : ZoomAnimationConfig := {
  lerpFactor := 0.25
  snapThreshold := 0.02
  easing := .easeOut
}

/-- Smooth zoom animation (more gradual) -/
def smoothZoomAnimationConfig : ZoomAnimationConfig := {
  lerpFactor := 0.10
  snapThreshold := 0.005
  easing := .easeInOut
}

-- ============================================================================
-- Map Bounds Configuration
-- ============================================================================

/-- Geographic bounding box for constraining the map view -/
structure MapBounds where
  /-- Minimum latitude (south) -/
  minLat : Float := -maxMercatorLatitude
  /-- Maximum latitude (north) -/
  maxLat : Float := maxMercatorLatitude
  /-- Minimum longitude (west) -/
  minLon : Float := -180.0
  /-- Maximum longitude (east) -/
  maxLon : Float := 180.0
  /-- Minimum allowed zoom level -/
  minZoom : Int := minZoomLevel
  /-- Maximum allowed zoom level -/
  maxZoom : Int := maxZoomLevel
  deriving Repr, Inhabited

namespace MapBounds

/-- Default bounds: entire world -/
def world : MapBounds := {}

/-- Check if a lat/lon point is within bounds -/
def contains (bounds : MapBounds) (lat lon : Float) : Bool :=
  lat >= bounds.minLat && lat <= bounds.maxLat &&
  lon >= bounds.minLon && lon <= bounds.maxLon

/-- Check if a zoom level is within bounds -/
def isValidZoom (bounds : MapBounds) (zoom : Int) : Bool :=
  zoom >= bounds.minZoom && zoom <= bounds.maxZoom

/-- Clamp latitude to bounds -/
def clampLat (bounds : MapBounds) (lat : Float) : Float :=
  floatClamp lat bounds.minLat bounds.maxLat

/-- Clamp longitude to bounds (with wrapping consideration) -/
def clampLon (bounds : MapBounds) (lon : Float) : Float :=
  -- First wrap, then clamp
  let wrapped := wrapLongitude lon
  floatClamp wrapped bounds.minLon bounds.maxLon

/-- Clamp zoom to bounds -/
def clampZoom (bounds : MapBounds) (zoom : Int) : Int :=
  intClamp zoom bounds.minZoom bounds.maxZoom

/-- Create bounds for a specific region -/
def region (minLat maxLat minLon maxLon : Float)
    (minZoom : Int := minZoomLevel) (maxZoom : Int := maxZoomLevel) : MapBounds := {
  minLat := minLat
  maxLat := maxLat
  minLon := minLon
  maxLon := maxLon
  minZoom := minZoom
  maxZoom := maxZoom
}

-- Some preset regions

/-- Continental United States bounds -/
def usa : MapBounds := region 24.0 50.0 (-125.0) (-66.0) 3 19

/-- Europe bounds -/
def europe : MapBounds := region 35.0 72.0 (-25.0) 45.0 3 19

/-- San Francisco Bay Area bounds -/
def sfBayArea : MapBounds := region 37.0 38.5 (-123.0) (-121.5) 8 19

end MapBounds

end Worldmap

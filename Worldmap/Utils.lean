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

end Worldmap

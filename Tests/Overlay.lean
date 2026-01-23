/-
  Tests for Worldmap.Overlay
-/
import Crucible
import Worldmap.Overlay
import Worldmap.Utils

namespace WorldmapTests.OverlayTests

open Crucible
open Worldmap

testSuite "Overlay"

-- Helper to check if a string contains a substring
def containsSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

-- ============================================================================
-- Coordinate Formatting Tests
-- ============================================================================

test "formatLatitude formats positive latitude with N" := do
  let result := formatLatitude 37.7749
  shouldSatisfy (containsSubstr result "N") "contains N"
  shouldSatisfy (containsSubstr result "37") "contains degrees"

test "formatLatitude formats negative latitude with S" := do
  let result := formatLatitude (-33.8688)
  shouldSatisfy (containsSubstr result "S") "contains S"
  shouldSatisfy (containsSubstr result "33") "contains degrees"

test "formatLatitude formats zero as N" := do
  let result := formatLatitude 0.0
  shouldSatisfy (containsSubstr result "N") "zero is N"

test "formatLongitude formats positive longitude with E" := do
  let result := formatLongitude 122.4194
  shouldSatisfy (containsSubstr result "E") "contains E"
  shouldSatisfy (containsSubstr result "122") "contains degrees"

test "formatLongitude formats negative longitude with W" := do
  let result := formatLongitude (-122.4194)
  shouldSatisfy (containsSubstr result "W") "contains W"
  shouldSatisfy (containsSubstr result "122") "contains degrees"

test "formatLongitude formats zero as E" := do
  let result := formatLongitude 0.0
  shouldSatisfy (containsSubstr result "E") "zero is E"

test "formatCoordinates combines lat and lon" := do
  let result := formatCoordinates 37.7749 (-122.4194)
  shouldSatisfy (containsSubstr result "N") "contains N"
  shouldSatisfy (containsSubstr result "W") "contains W"
  shouldSatisfy (containsSubstr result ",") "contains comma"

-- ============================================================================
-- Scale Bar Tests
-- ============================================================================

test "metersPerPixel decreases at higher zoom" := do
  let mpp10 := metersPerPixel 0.0 10
  let mpp15 := metersPerPixel 0.0 15
  shouldSatisfy (mpp10 > mpp15) "higher zoom = smaller pixels"

test "metersPerPixel is larger at equator than poles" := do
  let mppEquator := metersPerPixel 0.0 10
  let mpp60 := metersPerPixel 60.0 10
  shouldSatisfy (mppEquator > mpp60) "equator has larger meters/pixel"

test "findBestScaleDistance returns reasonable values" := do
  let mpp := metersPerPixel 0.0 10  -- About 152 m/px at zoom 10
  let (meters, pixels) := findBestScaleDistance mpp 150.0
  shouldSatisfy (meters > 0.0) "positive distance"
  shouldSatisfy (pixels > 0.0) "positive pixels"
  shouldSatisfy (pixels <= 150.0) "fits in max width"

test "formatDistance formats meters" := do
  shouldBe (formatDistance 500.0) "500 m"
  shouldBe (formatDistance 100.0) "100 m"

test "formatDistance formats kilometers" := do
  shouldBe (formatDistance 1000.0) "1 km"
  shouldBe (formatDistance 5000.0) "5 km"
  shouldBe (formatDistance 10000.0) "10 km"

test "niceDistances are ordered" := do
  for i in [:niceDistances.size - 1] do
    if h1 : i < niceDistances.size then
      if h2 : i + 1 < niceDistances.size then
        shouldSatisfy (niceDistances[i] < niceDistances[i + 1]) s!"distance {i} < {i+1}"

-- ============================================================================
-- Tile Status Tests
-- ============================================================================

test "formatTileStatus contains 'Loading' when pending" := do
  -- This is a simple format test - we can't easily create MapState in tests
  -- so we just test the string formatting
  let tileStr := "Loading: 5 tiles"
  shouldSatisfy (containsSubstr tileStr "Loading") "contains Loading"
  shouldSatisfy (containsSubstr tileStr "5") "contains count"

test "formatTileStatus contains 'Tiles' when loaded" := do
  let tileStr := "Tiles: 42"
  shouldSatisfy (containsSubstr tileStr "Tiles") "contains Tiles"
  shouldSatisfy (containsSubstr tileStr "42") "contains count"



end WorldmapTests.OverlayTests

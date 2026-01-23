/-
  Tests for Worldmap.Utils
-/
import Crucible
import Worldmap.Utils

namespace WorldmapTests.UtilsTests

open Crucible
open Worldmap

testSuite "Utils"

test "intToFloat converts correctly" := do
  shouldBe (intToFloat 0) 0.0
  shouldBe (intToFloat 42) 42.0
  shouldBe (intToFloat (-10)) (-10.0)

test "natToInt converts correctly" := do
  shouldBe (natToInt 0) 0
  shouldBe (natToInt 100) 100

test "intMax returns maximum" := do
  shouldBe (intMax 5 10) 10
  shouldBe (intMax 10 5) 10
  shouldBe (intMax (-5) 5) 5
  shouldBe (intMax 7 7) 7

test "intMin returns minimum" := do
  shouldBe (intMin 5 10) 5
  shouldBe (intMin 10 5) 5
  shouldBe (intMin (-5) 5) (-5)
  shouldBe (intMin 7 7) 7

test "floatMax returns maximum" := do
  shouldBe (floatMax 5.0 10.0) 10.0
  shouldBe (floatMax 10.0 5.0) 10.0
  shouldBe (floatMax (-5.0) 5.0) 5.0

test "floatMin returns minimum" := do
  shouldBe (floatMin 5.0 10.0) 5.0
  shouldBe (floatMin 10.0 5.0) 5.0
  shouldBe (floatMin (-5.0) 5.0) (-5.0)

test "floatClamp clamps to range" := do
  shouldBe (floatClamp 5.0 0.0 10.0) 5.0
  shouldBe (floatClamp (-5.0) 0.0 10.0) 0.0
  shouldBe (floatClamp 15.0 0.0 10.0) 10.0
  shouldBe (floatClamp 0.0 0.0 10.0) 0.0
  shouldBe (floatClamp 10.0 0.0 10.0) 10.0

test "clampLatitude clamps to Mercator range" := do
  shouldBe (clampLatitude 45.0) 45.0
  shouldBe (clampLatitude 90.0) maxMercatorLatitude
  shouldBe (clampLatitude (-90.0)) (-maxMercatorLatitude)
  shouldBe (clampLatitude 0.0) 0.0

test "wrapLongitude wraps to [-180, 180]" := do
  shouldBe (wrapLongitude 0.0) 0.0
  shouldBe (wrapLongitude 180.0) 180.0
  shouldBe (wrapLongitude (-180.0)) (-180.0)
  shouldBe (wrapLongitude 181.0) (-179.0)
  shouldBe (wrapLongitude (-181.0)) 179.0
  shouldBe (wrapLongitude 270.0) (-90.0)

test "clampZoom clamps to valid range" := do
  shouldBe (clampZoom 10) 10
  shouldBe (clampZoom 0) 0
  shouldBe (clampZoom 19) 19
  shouldBe (clampZoom (-5)) 0
  shouldBe (clampZoom 25) 19

test "defaultMaxCachedImages is 1500" := do
  shouldBe defaultMaxCachedImages 1500

test "defaultDiskCacheSizeBytes is 100MB" := do
  shouldBe defaultDiskCacheSizeBytes (100 * 1024 * 1024)

test "defaultTileSize is 512" := do
  shouldBe defaultTileSize 512

-- ============================================================================
-- EasingType Tests
-- ============================================================================

test "EasingType.linear returns input unchanged" := do
  shouldBe (EasingType.apply .linear 0.0) 0.0
  shouldBe (EasingType.apply .linear 0.5) 0.5
  shouldBe (EasingType.apply .linear 1.0) 1.0

test "EasingType.easeOut is 0 at start and 1 at end" := do
  shouldBe (EasingType.apply .easeOut 0.0) 0.0
  shouldBe (EasingType.apply .easeOut 1.0) 1.0

test "EasingType.easeOut is faster than linear at midpoint" := do
  let easeValue := EasingType.apply .easeOut 0.5
  shouldSatisfy (easeValue > 0.5) "easeOut at 0.5 > 0.5"

test "EasingType.easeInOut is 0 at start and 1 at end" := do
  shouldBe (EasingType.apply .easeInOut 0.0) 0.0
  shouldBe (EasingType.apply .easeInOut 1.0) 1.0

test "EasingType.easeInOut equals linear at midpoint" := do
  shouldBe (EasingType.apply .easeInOut 0.5) 0.5

-- ============================================================================
-- ZoomAnimationConfig Tests
-- ============================================================================

test "defaultZoomAnimationConfig has expected values" := do
  shouldBe defaultZoomAnimationConfig.lerpFactor 0.15
  shouldBe defaultZoomAnimationConfig.snapThreshold 0.01
  shouldBe (defaultZoomAnimationConfig.easing == .linear) true

test "fastZoomAnimationConfig has faster lerp" := do
  shouldSatisfy (fastZoomAnimationConfig.lerpFactor > defaultZoomAnimationConfig.lerpFactor) "faster lerp"
  shouldBe (fastZoomAnimationConfig.easing == .easeOut) true

test "smoothZoomAnimationConfig has slower lerp" := do
  shouldSatisfy (smoothZoomAnimationConfig.lerpFactor < defaultZoomAnimationConfig.lerpFactor) "slower lerp"
  shouldBe (smoothZoomAnimationConfig.easing == .easeInOut) true

-- ============================================================================
-- MapBounds Tests
-- ============================================================================

test "MapBounds.world covers full world" := do
  let bounds := MapBounds.world
  shouldBe bounds.minLat (-maxMercatorLatitude)
  shouldBe bounds.maxLat maxMercatorLatitude
  shouldBe bounds.minLon (-180.0)
  shouldBe bounds.maxLon 180.0
  shouldBe bounds.minZoom 0
  shouldBe bounds.maxZoom 19

test "MapBounds.contains returns true for valid points" := do
  let bounds := MapBounds.world
  shouldBe (bounds.contains 0.0 0.0) true
  shouldBe (bounds.contains 45.0 (-122.0)) true
  shouldBe (bounds.contains (-85.0) 180.0) true

test "MapBounds.contains returns false for out of bounds points" := do
  let bounds := MapBounds.sfBayArea
  shouldBe (bounds.contains 0.0 0.0) false  -- Equator, prime meridian
  shouldBe (bounds.contains 90.0 0.0) false  -- North pole

test "MapBounds.isValidZoom returns true for valid zoom" := do
  let bounds := MapBounds.world
  shouldBe (bounds.isValidZoom 0) true
  shouldBe (bounds.isValidZoom 10) true
  shouldBe (bounds.isValidZoom 19) true

test "MapBounds.isValidZoom returns false for invalid zoom" := do
  let bounds := MapBounds.sfBayArea  -- minZoom 8, maxZoom 19
  shouldBe (bounds.isValidZoom 5) false  -- Below min
  shouldBe (bounds.isValidZoom 20) false  -- Above max

test "MapBounds.clampLat clamps to bounds" := do
  let bounds := MapBounds.usa  -- 24.0 to 50.0
  shouldBe (bounds.clampLat 37.0) 37.0  -- Within bounds
  shouldBe (bounds.clampLat 10.0) 24.0  -- Below min
  shouldBe (bounds.clampLat 60.0) 50.0  -- Above max

test "MapBounds.clampLon clamps and wraps" := do
  let bounds := MapBounds.usa  -- -125.0 to -66.0
  shouldBe (bounds.clampLon (-100.0)) (-100.0)  -- Within bounds
  shouldBe (bounds.clampLon (-130.0)) (-125.0)  -- Below min
  shouldBe (bounds.clampLon (-50.0)) (-66.0)    -- Above max

test "MapBounds.clampZoom clamps to bounds" := do
  let bounds := MapBounds.sfBayArea  -- minZoom 8, maxZoom 19
  shouldBe (bounds.clampZoom 10) 10  -- Within bounds
  shouldBe (bounds.clampZoom 5) 8    -- Below min
  shouldBe (bounds.clampZoom 25) 19  -- Above max

test "MapBounds.region creates custom bounds" := do
  let bounds := MapBounds.region 30.0 40.0 (-120.0) (-110.0) 5 15
  shouldBe bounds.minLat 30.0
  shouldBe bounds.maxLat 40.0
  shouldBe bounds.minLon (-120.0)
  shouldBe bounds.maxLon (-110.0)
  shouldBe bounds.minZoom 5
  shouldBe bounds.maxZoom 15

test "preset bounds have reasonable values" := do
  -- USA
  shouldSatisfy (MapBounds.usa.minLat > 20.0) "USA south"
  shouldSatisfy (MapBounds.usa.maxLat < 55.0) "USA north"
  -- Europe
  shouldSatisfy (MapBounds.europe.minLat > 30.0) "Europe south"
  shouldSatisfy (MapBounds.europe.maxLat < 75.0) "Europe north"
  -- SF Bay Area
  shouldSatisfy (MapBounds.sfBayArea.minLat > 36.0) "SF south"
  shouldSatisfy (MapBounds.sfBayArea.maxLat < 39.0) "SF north"



end WorldmapTests.UtilsTests

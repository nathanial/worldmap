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

#generate_tests

end WorldmapTests.UtilsTests

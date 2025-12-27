/-
  Tests for Worldmap.KeyCode
-/
import Crucible
import Worldmap.KeyCode

namespace WorldmapTests.KeyCodeTests

open Crucible
open Worldmap.KeyCode

testSuite "KeyCode"

-- Arrow key tests
test "arrow keys have distinct codes" := do
  shouldSatisfy (arrowUp != arrowDown) "up != down"
  shouldSatisfy (arrowUp != arrowLeft) "up != left"
  shouldSatisfy (arrowUp != arrowRight) "up != right"
  shouldSatisfy (arrowDown != arrowLeft) "down != left"
  shouldSatisfy (arrowDown != arrowRight) "down != right"
  shouldSatisfy (arrowLeft != arrowRight) "left != right"

test "arrow keys have expected macOS key codes" := do
  shouldBe arrowUp 126
  shouldBe arrowDown 125
  shouldBe arrowLeft 123
  shouldBe arrowRight 124

-- Number key tests
test "number keys have distinct codes" := do
  let keys := [key0, key1, key2, key3, key4, key5, key6, key7, key8, key9]
  -- Check all pairs are distinct
  for i in [:keys.length] do
    for j in [i+1:keys.length] do
      if h1 : i < keys.length then
        if h2 : j < keys.length then
          shouldSatisfy (keys[i] != keys[j]) s!"key{i} != key{j}"

-- toZoomLevel tests
test "toZoomLevel maps number keys to zoom levels" := do
  shouldBe (toZoomLevel key1) (some 1)
  shouldBe (toZoomLevel key2) (some 2)
  shouldBe (toZoomLevel key3) (some 3)
  shouldBe (toZoomLevel key4) (some 4)
  shouldBe (toZoomLevel key5) (some 5)
  shouldBe (toZoomLevel key6) (some 6)
  shouldBe (toZoomLevel key7) (some 7)
  shouldBe (toZoomLevel key8) (some 8)
  shouldBe (toZoomLevel key9) (some 9)

test "toZoomLevel maps key0 to zoom 10" := do
  shouldBe (toZoomLevel key0) (some 10)

test "toZoomLevel returns none for non-numeric keys" := do
  shouldBe (toZoomLevel arrowUp) none
  shouldBe (toZoomLevel arrowDown) none
  shouldBe (toZoomLevel space) none
  shouldBe (toZoomLevel escape) none
  shouldBe (toZoomLevel home) none

-- Symbol key tests
test "navigation keys have expected codes" := do
  shouldBe home 115
  shouldBe escape 53
  shouldBe space 49

test "plus and minus keys for zoom" := do
  shouldBe equal 24   -- + key (with shift)
  shouldBe minus 27   -- - key

#generate_tests

end WorldmapTests.KeyCodeTests

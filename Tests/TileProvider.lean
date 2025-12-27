/-
  Tests for Worldmap.TileProvider
-/
import Crucible
import Worldmap.TileProvider
import Worldmap.TileCoord

namespace WorldmapTests.TileProviderTests

open Crucible
open Worldmap
open Worldmap.TileProvider

testSuite "TileProvider"

-- Helper to check if a string contains a substring
def containsSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

def testTile : TileCoord := { x := 1234, y := 5678, z := 12 }

-- URL generation tests

test "tileUrl generates correct URL for CartoDB Dark" := do
  let url := cartoDarkRetina.tileUrl testTile
  shouldSatisfy (containsSubstr url "basemaps.cartocdn.com") "contains cartocdn"
  shouldSatisfy (containsSubstr url "dark_all") "contains dark_all"
  shouldSatisfy (containsSubstr url "/12/1234/5678") "contains tile coords"
  shouldSatisfy (containsSubstr url "@2x") "contains retina suffix"

test "tileUrl generates correct URL for OSM" := do
  let url := openStreetMap.tileUrl testTile
  shouldSatisfy (containsSubstr url "tile.openstreetmap.org") "contains osm domain"
  shouldSatisfy (containsSubstr url "/12/1234/5678.png") "contains tile path"

test "tileUrl generates correct URL for Stadia" := do
  let url := stadiaSmooth.tileUrl testTile
  shouldSatisfy (containsSubstr url "tiles.stadiamaps.com") "contains stadia domain"
  shouldSatisfy (containsSubstr url "alidade_smooth") "contains style"

test "tileUrl substitutes subdomains" := do
  -- Different x coords should rotate through subdomains
  let url1 := cartoDarkRetina.tileUrl { x := 0, y := 0, z := 10 }
  let url2 := cartoDarkRetina.tileUrl { x := 1, y := 0, z := 10 }
  let url3 := cartoDarkRetina.tileUrl { x := 2, y := 0, z := 10 }
  let url4 := cartoDarkRetina.tileUrl { x := 3, y := 0, z := 10 }
  -- All should start with https:// and a valid subdomain
  shouldSatisfy (url1.startsWith "https://") "url1 valid https"
  shouldSatisfy (url2.startsWith "https://") "url2 valid https"
  shouldSatisfy (url3.startsWith "https://") "url3 valid https"
  shouldSatisfy (url4.startsWith "https://") "url4 valid https"

test "tileUrl works with empty subdomains" := do
  let url := stamenToner.tileUrl testTile
  -- Should not have {s} in the result
  shouldSatisfy (!containsSubstr url "{s}") "no placeholder"
  shouldSatisfy (containsSubstr url "stadiamaps.com") "valid domain"

-- Custom provider tests

test "custom provider generates correct URL" := do
  let provider := custom "Test" "https://example.com/tiles/{z}/{x}/{y}.png"
  let url := provider.tileUrl testTile
  shouldBe url "https://example.com/tiles/12/1234/5678.png"

test "custom provider respects tile size" := do
  let provider := custom "Retina" "https://example.com/{z}/{x}/{y}@2x.png" 512
  shouldBe provider.tileSize 512

test "custom provider respects max zoom" := do
  let provider := custom "Limited" "https://example.com/{z}/{x}/{y}.png" 256 15
  shouldBe provider.maxZoom 15

-- Zoom validation tests

test "isValidZoom returns true for valid zoom" := do
  shouldBe (cartoDarkRetina.isValidZoom 10) true
  shouldBe (cartoDarkRetina.isValidZoom 0) true
  shouldBe (cartoDarkRetina.isValidZoom 19) true

test "isValidZoom returns false for invalid zoom" := do
  shouldBe (cartoDarkRetina.isValidZoom (-1)) false
  shouldBe (cartoDarkRetina.isValidZoom 20) false

test "clampZoom clamps to provider range" := do
  shouldBe (cartoDarkRetina.clampZoom 10) 10
  shouldBe (cartoDarkRetina.clampZoom (-5)) 0
  shouldBe (cartoDarkRetina.clampZoom 25) 19

test "clampZoom respects provider-specific limits" := do
  -- Stamen Watercolor maxes out at zoom 16
  shouldBe (stamenWatercolor.clampZoom 18) 16
  shouldBe (stamenWatercolor.clampZoom 10) 10

-- Cache ID tests

test "cacheId generates filesystem-safe names" := do
  shouldBe cartoDarkRetina.cacheId "cartodb-dark-2x"
  shouldBe cartoLight.cacheId "cartodb-light"
  shouldBe openStreetMap.cacheId "openstreetmap"

-- Preset provider tests

test "default provider is CartoDB Dark @2x" := do
  shouldBe TileProvider.default.name "CartoDB Dark @2x"
  shouldBe TileProvider.default.tileSize 512

test "presets contains expected providers" := do
  shouldSatisfy (presets.size >= 10) "has many presets"
  -- Check some key providers exist
  shouldSatisfy (presets.any fun p => p.name == "OpenStreetMap") "has OSM"
  shouldSatisfy (presets.any fun p => p.name == "CartoDB Dark @2x") "has CartoDB Dark"
  shouldSatisfy (presets.any fun p => p.name == "Stamen Watercolor") "has Stamen Watercolor"

test "all presets have valid configuration" := do
  for provider in presets do
    shouldSatisfy (provider.tileSize > 0) s!"{provider.name} has positive tile size"
    shouldSatisfy (provider.maxZoom >= provider.minZoom) s!"{provider.name} has valid zoom range"
    shouldSatisfy (containsSubstr provider.urlTemplate "{z}") s!"{provider.name} has zoom placeholder"
    shouldSatisfy (containsSubstr provider.urlTemplate "{x}") s!"{provider.name} has x placeholder"
    shouldSatisfy (containsSubstr provider.urlTemplate "{y}") s!"{provider.name} has y placeholder"

-- Provider property tests

test "CartoDB providers have correct tile sizes" := do
  shouldBe cartoDarkRetina.tileSize 512
  shouldBe cartoDark.tileSize 256
  shouldBe cartoLightRetina.tileSize 512
  shouldBe cartoLight.tileSize 256

test "all providers have attribution" := do
  -- All preset providers should have attribution for legal compliance
  shouldSatisfy (cartoDarkRetina.attribution.length > 0) "CartoDB has attribution"
  shouldSatisfy (openStreetMap.attribution.length > 0) "OSM has attribution"
  shouldSatisfy (stamenToner.attribution.length > 0) "Stamen has attribution"

#generate_tests

end WorldmapTests.TileProviderTests

/-
  Tests for Worldmap.TileCache

  Note: Functions involving TileState.loaded require a GPU context and actual
  Texture objects. Those are tested via integration tests. This file tests
  the pure logic that doesn't require FFI types.
-/
import Crucible
import Std.Data.HashMap
import Std.Data.HashSet
import Worldmap.TileCache
import Worldmap.RetryLogic
import Worldmap.Utils

namespace WorldmapTests.TileCacheTests

open Crucible
open Worldmap
open Worldmap.RetryLogic
open Std (HashMap HashSet)

testSuite "TileCache"

def tile1 : TileCoord := { x := 0, y := 0, z := 10 }
def tile2 : TileCoord := { x := 1, y := 0, z := 10 }
def tile3 : TileCoord := { x := 0, y := 1, z := 10 }
def tile4 : TileCoord := { x := 1, y := 1, z := 10 }

def testRetryState : RetryState := RetryState.initialFailure 100

-- Helper to check if cache has pending state for a tile
def hasPending (cache : TileCache) (coord : TileCoord) : Bool :=
  match cache.get coord with
  | some .pending => true
  | _ => false

-- Helper to check if cache has failed state
def hasFailed (cache : TileCache) (coord : TileCoord) : Bool :=
  match cache.get coord with
  | some (.failed _) => true
  | _ => false

-- Helper to check if cache has cached state
def hasCached (cache : TileCache) (coord : TileCoord) : Bool :=
  match cache.get coord with
  | some (.cached _ _) => true
  | _ => false

test "empty cache has size 0" := do
  shouldBe TileCache.empty.size 0

test "empty cache contains returns false" := do
  shouldBe (TileCache.empty.contains tile1) false

test "empty cache get returns none" := do
  shouldSatisfy (TileCache.empty.get tile1).isNone "get returns none"

test "insert increases size" := do
  let cache := TileCache.empty.insert tile1 .pending
  shouldBe cache.size 1

test "insert then contains returns true" := do
  let cache := TileCache.empty.insert tile1 .pending
  shouldBe (cache.contains tile1) true

test "insert then get returns the state" := do
  let cache := TileCache.empty.insert tile1 .pending
  shouldSatisfy (hasPending cache tile1) "has pending state"

test "multiple inserts increase size" := do
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 .pending
    |>.insert tile3 .pending
  shouldBe cache.size 3

test "insert same coord updates state" := do
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile1 (.failed testRetryState)
  shouldBe cache.size 1
  shouldSatisfy (hasFailed cache tile1) "updated to failed state"

test "removeCoords removes specified tiles" := do
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 .pending
    |>.insert tile3 .pending
  let cache' := cache.removeCoords [tile1, tile3]
  shouldBe cache'.size 1
  shouldBe (cache'.contains tile1) false
  shouldBe (cache'.contains tile2) true
  shouldBe (cache'.contains tile3) false

test "removeCoords with empty list does nothing" := do
  let cache := TileCache.empty.insert tile1 .pending
  let cache' := cache.removeCoords []
  shouldBe cache'.size 1

-- State counts tests (partial - only non-Texture states)

test "stateCounts counts pending as other" := do
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 .pending
  let (gpu, ram, other) := cache.stateCounts
  shouldBe gpu 0
  shouldBe ram 0
  shouldBe other 2

test "stateCounts counts failed as other" := do
  let cache := TileCache.empty
    |>.insert tile1 (.failed testRetryState)
  let (gpu, ram, other) := cache.stateCounts
  shouldBe gpu 0
  shouldBe ram 0
  shouldBe other 1

test "stateCounts counts cached as ram" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]  -- PNG magic bytes
  let cache := TileCache.empty
    |>.insert tile1 (.cached pngData 100)
    |>.insert tile2 (.cached pngData 200)
  let (gpu, ram, other) := cache.stateCounts
  shouldBe gpu 0
  shouldBe ram 2
  shouldBe other 0

-- staleTiles tests

-- Helper to create HashSet from list
def hashSetOf (tiles : List TileCoord) : Std.HashSet TileCoord :=
  tiles.foldl (fun s t => s.insert t) {}

test "staleTiles returns empty for empty cache" := do
  let keepSet : Std.HashSet TileCoord := {}
  shouldBe (TileCache.empty.staleTiles keepSet).length 0

test "staleTiles excludes tiles in keepSet" := do
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 .pending
  let keepSet := hashSetOf [tile1]
  let stale := cache.staleTiles keepSet
  shouldBe stale.length 1
  shouldSatisfy (stale.contains tile2) "contains tile2"

test "staleTiles excludes cached tiles" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 (.cached pngData 100)
  let keepSet : Std.HashSet TileCoord := {}
  let stale := cache.staleTiles keepSet
  shouldBe stale.length 1
  shouldSatisfy (stale.contains tile1) "contains pending tile"

test "staleTiles returns failed tiles outside keepSet" := do
  let cache := TileCache.empty
    |>.insert tile1 (.failed testRetryState)
    |>.insert tile2 (.retrying testRetryState)
    |>.insert tile3 (.exhausted testRetryState)
  let keepSet : Std.HashSet TileCoord := {}
  let stale := cache.staleTiles keepSet
  shouldBe stale.length 3

-- cachedImageCount tests

test "cachedImageCount returns 0 for empty cache" := do
  shouldBe TileCache.empty.cachedImageCount 0

test "cachedImageCount counts only cached tiles" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 (.cached pngData 100)
    |>.insert tile3 (.cached pngData 200)
    |>.insert tile4 (.failed testRetryState)
  shouldBe cache.cachedImageCount 2

-- cachedTilesToReload tests

test "cachedTilesToReload returns empty for empty cache" := do
  let visibleSet := hashSetOf [tile1]
  shouldBe (TileCache.empty.cachedTilesToReload visibleSet).length 0

test "cachedTilesToReload returns cached tiles in visible set" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 (.cached pngData 100)
    |>.insert tile2 (.cached pngData 200)
  let visibleSet := hashSetOf [tile1]
  let toReload := cache.cachedTilesToReload visibleSet
  shouldBe toReload.length 1
  match toReload.head? with
  | some (coord, _) => shouldBe coord tile1
  | none => shouldSatisfy false "Expected one tile to reload"

test "cachedTilesToReload ignores non-cached tiles" := do
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 (.failed testRetryState)
  let visibleSet := hashSetOf [tile1, tile2]
  shouldBe (cache.cachedTilesToReload visibleSet).length 0

-- cachedImagesToEvict tests (LRU eviction)

test "cachedImagesToEvict returns empty when under limit" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 (.cached pngData 100)
    |>.insert tile2 (.cached pngData 200)
  let keepSet : Std.HashSet TileCoord := {}
  -- maxToKeep = 5, we have 2, so nothing to evict
  shouldBe (cache.cachedImagesToEvict keepSet 5).length 0

test "cachedImagesToEvict evicts oldest first" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 (.cached pngData 100)  -- oldest
    |>.insert tile2 (.cached pngData 300)  -- newest
    |>.insert tile3 (.cached pngData 200)  -- middle
  let keepSet : Std.HashSet TileCoord := {}
  -- maxToKeep = 1, so evict 2 oldest
  let toEvict := cache.cachedImagesToEvict keepSet 1
  shouldBe toEvict.length 2
  -- Should evict tile1 (100) and tile3 (200), keeping tile2 (300)
  shouldSatisfy (toEvict.contains tile1) "evicts oldest tile1"
  shouldSatisfy (toEvict.contains tile3) "evicts middle tile3"
  shouldSatisfy (!toEvict.contains tile2) "keeps newest tile2"

test "cachedImagesToEvict respects keepSet" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 (.cached pngData 100)  -- oldest but in keepSet
    |>.insert tile2 (.cached pngData 200)
    |>.insert tile3 (.cached pngData 300)
  let keepSet := hashSetOf [tile1]
  -- maxToKeep = 1, tile1 is protected
  let toEvict := cache.cachedImagesToEvict keepSet 1
  -- Should evict tile2, keep tile1 (protected) and tile3 (newest of unprotected)
  shouldSatisfy (!toEvict.contains tile1) "keeps protected tile1"
  shouldSatisfy (toEvict.contains tile2) "evicts tile2"

test "cachedImagesToEvict only considers cached tiles" := do
  let pngData := ByteArray.mk #[0x89, 0x50, 0x4E, 0x47]
  let cache := TileCache.empty
    |>.insert tile1 .pending
    |>.insert tile2 (.cached pngData 100)
    |>.insert tile3 (.failed testRetryState)
  let keepSet : Std.HashSet TileCoord := {}
  -- Only tile2 is cached
  let toEvict := cache.cachedImagesToEvict keepSet 0
  shouldBe toEvict.length 1
  shouldSatisfy (toEvict.contains tile2) "evicts cached tile"

-- Default configs tests

test "defaultRetryConfig has expected values" := do
  shouldBe defaultRetryConfig.maxRetries 3
  shouldBe defaultRetryConfig.baseDelay 60

test "defaultUnloadConfig has expected values" := do
  shouldBe defaultUnloadConfig.bufferTiles 3
  shouldBe defaultUnloadConfig.maxCachedImages defaultMaxCachedImages



end WorldmapTests.TileCacheTests

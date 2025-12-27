/-
  Predictive Tile Prefetching
  Predicts movement direction based on pan velocity and prefetches tiles ahead of viewport.
-/
import Worldmap.State
import Worldmap.Viewport
import Worldmap.TileCoord
import Std.Data.HashSet

namespace Worldmap

open Std (HashSet)

/-- Configuration for predictive prefetching -/
structure PrefetchConfig where
  /-- How far ahead to predict in milliseconds -/
  lookAheadMs : Float := 500.0
  /-- Minimum velocity magnitude to trigger prefetch (pixels/frame) -/
  minVelocity : Float := 5.0
  /-- Maximum tiles to prefetch per frame -/
  maxPrefetchTiles : Nat := 8
  /-- Assumed frame time in milliseconds (60fps default) -/
  frameTimeMs : Float := 16.67
  deriving Repr, Inhabited

/-- Default prefetch configuration -/
def defaultPrefetchConfig : PrefetchConfig := {}

/-- Fast prefetch configuration (shorter lookahead, more tiles) -/
def fastPrefetchConfig : PrefetchConfig := {
  lookAheadMs := 300.0
  maxPrefetchTiles := 12
}

/-- Conservative prefetch configuration (longer lookahead, fewer tiles) -/
def conservativePrefetchConfig : PrefetchConfig := {
  lookAheadMs := 750.0
  minVelocity := 10.0
  maxPrefetchTiles := 4
}

/-- Calculate the magnitude of the velocity vector -/
def velocityMagnitude (velX velY : Float) : Float :=
  Float.sqrt (velX * velX + velY * velY)

/-- Calculate tiles that should be prefetched based on current pan velocity.
    Returns tiles visible at predicted future position that aren't currently visible or cached. -/
def tilesForPrefetch (state : MapState) (config : PrefetchConfig := {}) : Array TileCoord :=
  -- Check if velocity is significant enough to trigger prefetch
  let velMag := velocityMagnitude state.panVelocityX state.panVelocityY
  if velMag < config.minVelocity then
    #[]
  else
    -- Calculate how many frames ahead to look
    let framesAhead := config.lookAheadMs / config.frameTimeMs

    -- Predict pixel offset based on velocity
    -- Note: velocity is pixels/frame, so multiply by frames
    let predictedDx := state.panVelocityX * framesAhead
    let predictedDy := state.panVelocityY * framesAhead

    -- Convert pixel offset to geographic offset
    let (dLon, dLat) := state.viewport.pixelsToDegrees predictedDx predictedDy

    -- Create predicted viewport (note: pan inverts the delta)
    -- When user drags right (positive velocity), map center moves left (negative lon change)
    let predictedViewport : MapViewport := { state.viewport with
      centerLat := clampLatitude (state.viewport.centerLat + dLat)
      centerLon := wrapLongitude (state.viewport.centerLon - dLon)
    }

    -- Get tiles visible at predicted position
    let predictedTiles := predictedViewport.visibleTiles

    -- Build set of currently visible tiles
    let currentTiles := state.viewport.visibleTiles
    let currentSet : HashSet TileCoord := currentTiles.foldl (fun s t => s.insert t) {}

    -- Filter to tiles not already visible and not in cache
    let prefetchCandidates := predictedTiles.filter fun t =>
      !currentSet.contains t && !state.cache.contains t

    -- Sort by distance from predicted center and take max
    let (centerTileX, centerTileY) := predictedViewport.centerTilePos
    let candidatesArray := prefetchCandidates.toArray
    let sorted := candidatesArray.qsort fun a b =>
      let distA := (intToFloat a.x - centerTileX) * (intToFloat a.x - centerTileX) +
                   (intToFloat a.y - centerTileY) * (intToFloat a.y - centerTileY)
      let distB := (intToFloat b.x - centerTileX) * (intToFloat b.x - centerTileX) +
                   (intToFloat b.y - centerTileY) * (intToFloat b.y - centerTileY)
      distA < distB

    sorted.take config.maxPrefetchTiles

/-- Check if prefetching should be active based on velocity -/
def shouldPrefetch (state : MapState) (config : PrefetchConfig := {}) : Bool :=
  velocityMagnitude state.panVelocityX state.panVelocityY >= config.minVelocity

/-- Get the predicted center position based on velocity -/
def predictedCenter (state : MapState) (config : PrefetchConfig := {}) : Float × Float :=
  let framesAhead := config.lookAheadMs / config.frameTimeMs
  let predictedDx := state.panVelocityX * framesAhead
  let predictedDy := state.panVelocityY * framesAhead
  let (dLon, dLat) := state.viewport.pixelsToDegrees predictedDx predictedDy
  (clampLatitude (state.viewport.centerLat + dLat),
   wrapLongitude (state.viewport.centerLon - dLon))

end Worldmap

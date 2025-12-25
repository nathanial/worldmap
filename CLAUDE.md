# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Worldmap is a Lean 4 tile-based map viewer with Web Mercator projection. Extracted from the Afferent graphics library, it provides:
- Interactive map panning and zooming
- Async tile loading with 3-tier caching (GPU/RAM/Disk)
- Web Mercator projection (EPSG:3857)
- Exponential backoff retry logic for failed fetches
- Smooth zoom animations with cursor anchoring

## Build Commands

**IMPORTANT:** Use `./build.sh` instead of `lake build` directly (sets `LEAN_CC=/usr/bin/clang` for proper macOS framework linking).

```bash
# Build the project
./build.sh

# Build and run
./run.sh
```

## Project Structure

```
worldmap/
├── build.sh               # Build script (use instead of lake build)
├── run.sh                 # Build and run script
├── lakefile.lean          # Lake build configuration
├── lean-toolchain         # Lean version (v4.26.0)
├── Main.lean              # Standalone map viewer application
│
├── Worldmap.lean          # Library root (imports all modules)
├── Worldmap/
│   ├── TileCoord.lean     # Tile coordinates, Web Mercator projection
│   ├── Viewport.lean      # Screen to geographic transforms
│   ├── Zoom.lean          # Zoom-to-point (zoom to cursor) functionality
│   ├── TileCache.lean     # In-memory tile cache with retry support
│   ├── TileDiskCache.lean # Disk cache using Cellar library
│   ├── State.lean         # Complete map application state
│   ├── Input.lean         # Mouse/keyboard input handling
│   ├── RetryLogic.lean    # Exponential backoff retry strategy
│   └── Render.lean        # Tile rendering and async loading
│
└── tile_cache/            # Cached map tiles (auto-generated)
```

## Key Modules

### TileCoord.lean
- `TileCoord` - Tile coordinates (x, y, z)
- `LatLon` - Geographic coordinates (latitude, longitude)
- `latLonToTile` - Web Mercator projection
- `tileUrl` - CartoDB Dark @2x tile URL generation

### Viewport.lean
- `MapViewport` - Viewport state (center, zoom, dimensions)
- `visibleTiles` - Calculate visible tiles in viewport
- `centerTilePos` - Fractional tile position for center
- `pixelsToDegrees` - Convert pixel delta to geographic delta

### Zoom.lean
- `zoomToPoint` - Zoom while keeping cursor position fixed
- `centerForAnchor` - Compute center for anchor point
- `screenToGeo` - Convert screen to geographic coordinates

### State.lean
- `MapState` - Complete application state
- `MapState.init` - Initialize centered on location
- Includes drag state, zoom animation, disk cache

### Render.lean
- `updateTileCache` - Main update loop (fetch, cache, retry)
- `render` - Render all visible tiles with fallbacks
- `spawnFetchTask` - Background HTTP fetch with caching

## Dependencies

- **afferent** - Graphics rendering (Metal GPU)
- **wisp** - HTTP client (libcurl FFI)
- **cellar** - Disk cache with LRU eviction
- **crucible** - Test framework

## Tile Cache

Tiles are cached in three tiers:
1. **GPU textures** - Fast, limited by VRAM
2. **RAM (PNG bytes)** - Medium, max 1500 images
3. **Disk** - Slow, max 100MB (configurable)

Tile URL pattern: `https://{a-d}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png`

## Controls

- **Drag** - Pan the map
- **Scroll wheel** - Zoom toward cursor position
- **Close window** - Exit

## Usage Example

```lean
import Worldmap

-- Initialize map centered on San Francisco at zoom 12
let diskConfig : Worldmap.TileDiskCacheConfig := {
  cacheDir := "./tile_cache"
  tilesetName := "carto-dark-2x"
  maxSizeBytes := 100 * 1024 * 1024
}
let state ← Worldmap.MapState.init 37.7749 (-122.4194) 12 1280 720 diskConfig

-- In main loop:
let state ← Worldmap.handleInput window state
let state := Worldmap.updateZoomAnimation state
Worldmap.cancelStaleTasks state
let state ← Worldmap.updateTileCache state
Worldmap.render renderer state
```

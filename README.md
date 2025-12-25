# Worldmap

A tile-based map viewer for Lean 4 with Web Mercator projection.

## Features

- **Interactive Navigation**: Pan by dragging, zoom with scroll wheel
- **Smooth Zoom Animation**: Zooms toward cursor position with smooth interpolation
- **3-Tier Caching**: GPU textures → RAM (PNG bytes) → Disk (LRU eviction)
- **Async Tile Loading**: Non-blocking HTTP fetches with background decoding
- **Retry Logic**: Exponential backoff for failed tile fetches
- **Fallback Rendering**: Parent tiles displayed while children load

## Requirements

- Lean 4.26.0
- macOS (Metal GPU rendering via Afferent)
- libcurl (for HTTP tile fetching)

## Building

```bash
# Build the project
./build.sh

# Build and run
./run.sh
```

## Controls

| Input | Action |
|-------|--------|
| Drag | Pan the map |
| Scroll wheel | Zoom in/out (toward cursor) |
| Close window | Exit |

## Usage

The standalone demo starts centered on San Francisco at zoom level 12:

```bash
./run.sh
```

### As a Library

```lean
import Worldmap

-- Initialize map centered on a location
let diskConfig : Worldmap.TileDiskCacheConfig := {
  cacheDir := "./tile_cache"
  tilesetName := "carto-dark-2x"
  maxSizeBytes := 100 * 1024 * 1024  -- 100MB
}
let state ← Worldmap.MapState.init 37.7749 (-122.4194) 12 1280 720 diskConfig

-- In your render loop:
let state ← Worldmap.handleInput window state
let state := Worldmap.updateZoomAnimation state
Worldmap.cancelStaleTasks state
let state ← Worldmap.updateTileCache state
Worldmap.render renderer state
```

## Architecture

```
Worldmap/
├── TileCoord.lean      # Tile coordinates, Web Mercator projection
├── Viewport.lean       # Screen ↔ geographic coordinate transforms
├── Zoom.lean           # Zoom-to-point (cursor anchoring)
├── TileCache.lean      # In-memory tile cache with retry state
├── TileDiskCache.lean  # Disk cache using Cellar library
├── State.lean          # Complete application state
├── Input.lean          # Mouse/keyboard handling
├── RetryLogic.lean     # Exponential backoff strategy
└── Render.lean         # Async loading and tile rendering
```

## Tile Source

Uses CartoDB Dark @2x tiles (512px retina):
```
https://{a-d}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png
```

## Dependencies

- **afferent** - Metal GPU rendering, Canvas API
- **wisp** - HTTP client (libcurl FFI)
- **cellar** - Disk cache with LRU eviction

## License

MIT License - see [LICENSE](LICENSE)

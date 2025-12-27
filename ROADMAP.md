# Worldmap Roadmap

This document outlines potential improvements, new features, and code cleanup opportunities for the Worldmap project.

## Current State

Worldmap is a functional tile-based map viewer with:
- Web Mercator projection (EPSG:3857)
- Smooth zoom animations with cursor anchoring
- 3-tier caching (GPU/RAM/Disk)
- Async tile loading with exponential backoff retry
- Parent tile fallback rendering
- Pan via drag, zoom via scroll wheel

---

## Priority 1: Code Cleanup ✅ COMPLETED

### Deduplicate Utility Functions ✅

Created `Worldmap/Utils.lean` with shared constants and utility functions:
- `pi`, `maxMercatorLatitude`, `minZoomLevel`, `maxZoomLevel`
- `defaultMaxCachedImages`, `defaultDiskCacheSizeBytes`, `defaultTileSize`
- `intToFloat`, `natToInt`, `intMax`, `intMin`, `floatMax`, `floatMin`
- `floatClamp`, `intClamp`, `clampLatitude`, `wrapLongitude`, `clampZoom`

### Remove Debug Logging ✅

- Removed `IO.println` debug output from `MapState.init`

### Named Constants for Magic Numbers ✅

| Constant | Value | Location |
|----------|-------|----------|
| `defaultMaxCachedImages` | 1500 | `Utils.lean` |
| `defaultDiskCacheSizeBytes` | 100 MB | `Utils.lean` |
| `defaultTileSize` | 512 | `Utils.lean` |
| `maxMercatorLatitude` | 85.0 | `Utils.lean` |
| `minZoomLevel` / `maxZoomLevel` | 0 / 19 | `Utils.lean` |

---

## Priority 2: Testing ✅ COMPLETED

### Test Suite ✅

Comprehensive test suite with **199 tests** across 12 suites:

- [x] **TileCoord tests** (12 tests)
  - `latLonToTile` / `tileToLatLon` round-trip consistency
  - Edge cases: poles, date line, zoom level 0 and 19
  - `parentTile` / `childTiles` relationship

- [x] **TileProvider tests** (18 tests)
  - URL generation for all preset providers
  - Subdomain rotation, custom templates
  - Zoom validation and clamping

- [x] **Viewport tests** (12 tests)
  - `visibleTiles` returns correct tile count
  - `pixelsToDegrees` consistency
  - `tileScreenPos` and `centerTilePos` inverse relationship

- [x] **Zoom tests** (12 tests)
  - `zoomToPoint` keeps anchor point fixed
  - `screenToGeo` / `geoToTile` consistency
  - Latitude clamping and longitude wrapping

- [x] **RetryLogic tests** (16 tests)
  - Exponential backoff timing
  - `shouldRetry` respects exhaustion
  - State transitions

- [x] **TileCache tests** (28 tests)
  - State transitions (pending → cached → evicted)
  - LRU eviction order
  - `staleTiles` and `cachedImagesToEvict` logic

- [x] **Utils tests** (31 tests)
  - Type conversions, clamping functions
  - Named constants verification
  - EasingType functions, ZoomAnimationConfig presets
  - MapBounds operations and preset regions

- [x] **KeyCode tests** (8 tests)
  - Arrow key codes, number key codes
  - `toZoomLevel` mapping

- [x] **Overlay tests** (15 tests)
  - Coordinate formatting, scale bar
  - `metersPerPixel`, tile status

- [x] **Marker tests** (24 tests)
  - MarkerColor, Marker, MarkerLayer
  - Viewport culling, hit testing

- [x] **Prefetch tests** (15 tests)
  - PrefetchConfig, velocity magnitude
  - `tilesForPrefetch`, `predictedCenter`

- [x] **RequestCoalescing tests** (8 tests)
  - `shouldFetchNewTiles` debounce logic
  - Zoom animation debouncing

### Test Infrastructure ✅

- `Tests/` directory with modular test files
- `test.sh` script for building and running tests
- `lake test` target in `lakefile.lean`

---

## Priority 3: Configuration & Flexibility ✅ COMPLETED

### Configurable Tile Provider ✅

Created `Worldmap/TileProvider.lean` with:

```lean
structure TileProvider where
  name : String
  urlTemplate : String  -- "{s}.example.com/{z}/{x}/{y}.png"
  subdomains : Array String := #["a", "b", "c", "d"]
  tileSize : Int := 256
  attribution : String := ""
  maxZoom : Int := 19
  minZoom : Int := 0
  deriving Repr, Inhabited
```

**13 preset providers implemented:**
- CartoDB: `cartoDarkRetina`, `cartoDark`, `cartoLightRetina`, `cartoLight`, `cartoVoyagerRetina`, `cartoVoyager`
- OpenStreetMap: `openStreetMap`
- Stamen/Stadia: `stamenToner`, `stamenTonerLite`, `stamenTerrain`, `stamenWatercolor`, `stadiaSmooth`, `stadiaSmoothDark`
- Custom: `TileProvider.custom name urlTemplate tileSize maxZoom`

**Integration:**
- `MapState` now includes `tileProvider` field
- `MapState.setProvider` clears cache and updates settings
- `MapViewport.tileSize` synced with provider
- Tile URLs generated via `TileProvider.tileUrl`

### Configurable Zoom Animation ✅

Added to `Worldmap/Utils.lean`:

```lean
inductive EasingType where
  | linear | easeOut | easeInOut
  deriving Repr, BEq, Inhabited

structure ZoomAnimationConfig where
  lerpFactor : Float := 0.15
  snapThreshold : Float := 0.01
  easing : EasingType := .linear
  deriving Repr, Inhabited
```

**Preset configurations:**
- `defaultZoomAnimationConfig` - Linear, moderate speed
- `fastZoomAnimationConfig` - EaseOut, faster feel
- `smoothZoomAnimationConfig` - EaseInOut, gradual

**Integration:**
- `MapState` now includes `zoomAnimationConfig` field
- `MapState.setZoomAnimationConfig` updates settings
- `Render.updateZoomAnimation` uses config from state

### Bounding Box Constraints ✅

Added to `Worldmap/Utils.lean`:

```lean
structure MapBounds where
  minLat : Float := -85.0
  maxLat : Float := 85.0
  minLon : Float := -180.0
  maxLon : Float := 180.0
  minZoom : Int := 0
  maxZoom : Int := 19
  deriving Repr, Inhabited
```

**Preset regions:**
- `MapBounds.world` - Full world view
- `MapBounds.usa` - Continental United States
- `MapBounds.europe` - European region
- `MapBounds.sfBayArea` - San Francisco Bay Area

**Integration:**
- `MapState` now includes `mapBounds` field
- `MapState.setBounds` clamps position to new bounds
- `Input.handlePanInput` respects bounds on drag
- `Input.handleZoomInput` respects bounds on zoom
- `MapState.init/setCenter/setZoom` all respect bounds

---

## Priority 4: New Features ✅ COMPLETED

### Keyboard Navigation ✅

Created `Worldmap/KeyCode.lean` with macOS virtual key codes and updated `Input.lean`:

| Key | Action |
|-----|--------|
| Arrow keys | Pan map (100px per press) |
| `+` / `=` | Zoom in (centered) |
| `-` | Zoom out (centered) |
| `Home` | Reset to initial view |
| `0`-`9` | Jump to zoom level (0→10, 1-9→1-9) |

**Integration:**
- `handleKeyboardInput` in `Input.lean`
- `MapState.initialLat/Lon/Zoom` for Home key reset
- `MapState.resetToInitial` method

### Coordinate Display ✅

Created `Worldmap/Overlay.lean` with coordinate formatting:

```lean
def formatLatitude (lat : Float) : String   -- e.g., "37.77490° N"
def formatLongitude (lon : Float) : String  -- e.g., "122.41940° W"
def formatCoordinates (lat lon : Float) : String
def getCursorCoordinates (state : MapState) : String
def getCenterCoordinates (state : MapState) : String
```

**Integration:**
- `cursorLat`, `cursorLon`, `cursorScreenX`, `cursorScreenY` in `MapState`
- `updateCursorPosition` called in `handleInput`

### Scale Bar ✅

Functions in `Worldmap/Overlay.lean`:

```lean
def metersPerPixel (lat : Float) (zoom : Int) : Float
def findBestScaleDistance (metersPerPx : Float) (maxPixels : Float) : Float × Float
def formatDistance (meters : Float) : String  -- e.g., "500 m", "2 km"
def getScaleBarInfo (state : MapState) : String × Float  -- (label, pixelWidth)
```

### Tile Loading Indicator ✅

Functions in `Worldmap/Overlay.lean`:

```lean
def getTileStatus (state : MapState) : Nat × Nat × Nat  -- (loaded, pending, failed)
def formatTileStatus (state : MapState) : String  -- e.g., "Loading: 5 tiles" or "Tiles: 42"
```

### Marker/Point Layer ✅

Created `Worldmap/Marker.lean` with full marker system:

```lean
structure MarkerColor where
  r : Float; g : Float; b : Float; a : Float

structure Marker where
  id : MarkerId
  lat : Float
  lon : Float
  label : Option String
  color : MarkerColor
  size : Float

structure MarkerLayer where
  markers : Array Marker
  visible : Bool
  nextId : MarkerId
```

**Functions:**
- `addMarker`, `removeMarker`, `clearMarkers`, `getMarker`, `updateMarker`
- `setLabel`, `setColor`, `setSize`, `moveMarker`
- `markersInView` for viewport culling
- `hitTest`, `hitTestAll` for click handling
- `markerScreenPos` using new `Zoom.geoToScreen`

**Preset colors:** `red`, `green`, `blue`, `yellow`, `orange`, `purple`, `white`, `black`

---

## Priority 5: Performance Optimizations (Partial)

### Predictive Tile Prefetching ✅

Created `Worldmap/Prefetch.lean` with velocity-based tile prefetching:

```lean
structure PrefetchConfig where
  lookAheadMs : Float := 500.0      -- predict 0.5 seconds ahead
  minVelocity : Float := 5.0        -- minimum velocity to trigger
  maxPrefetchTiles : Nat := 8       -- limit prefetch per frame

def tilesForPrefetch (state : MapState) (config : PrefetchConfig) : Array TileCoord
```

**Features:**
- Velocity tracking in `MapState` (`panVelocityX`, `panVelocityY`)
- Exponential smoothing of velocity in `Input.handlePanInput`
- Velocity decay when not dragging
- Predicts future viewport position and prefetches tiles ahead

**Preset configurations:** `defaultPrefetchConfig`, `fastPrefetchConfig`, `conservativePrefetchConfig`

### Request Coalescing ✅

Zoom debouncing to avoid fetching intermediate zoom levels during rapid scrolling:

```lean
-- Added to MapState:
lastZoomChangeFrame : Nat := 0     -- frame when zoom target changed
zoomDebounceFrames : Nat := 6      -- wait ~100ms at 60fps before fetching

def shouldFetchNewTiles (state : MapState) : Bool
```

**Integration:**
- `handleZoomInput` records `lastZoomChangeFrame` on zoom changes
- `updateTileCache` checks `shouldFetchNewTiles` before spawning fetch tasks
- Prevents wasted network requests during rapid zoom animations

### Connection Pooling ✅

Configured libcurl's multi-handle for better connection reuse in `wisp/native/src/wisp_ffi.c`:

```c
// In wisp_multi_init:
curl_multi_setopt(handle, CURLMOPT_MAXCONNECTS, 16L);    // Increase connection cache
curl_multi_setopt(handle, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX);  // HTTP/2 multiplexing
```

### Texture Atlas (Deferred)

**Reason:** High complexity (Metal shader changes, atlas allocation, defragmentation) for low benefit (Metal already handles many draw calls efficiently; tiles are uniform 512x512).

If needed later:
- Create 4096x4096 atlas texture (64 tile slots)
- Track slot allocation with simple free list
- Modify `drawTexturedRect` to accept UV coordinates within atlas
- Handle slot eviction when atlas is full

---

## Priority 6: Future Features

### Vector Tile Support

Support MVT (Mapbox Vector Tile) format:
- Parse PBF/MVT tile data
- Tessellate geometry
- Style-based rendering (roads, buildings, labels)

### GeoJSON Layer

Render GeoJSON overlays:
- Point, LineString, Polygon support
- Style customization
- Click/hover events

### Search/Geocoding

Integrate with geocoding API:
- Search box UI
- Nominatim or other provider
- Fly-to animation on result selection

### Mini-Map

Inset overview map:
- Fixed position corner widget
- Shows global view with viewport rectangle
- Click to jump to location

### Offline Mode

Pre-download tile regions:

```lean
structure OfflineRegion where
  name : String
  bounds : MapBounds
  minZoom : Int
  maxZoom : Int
  tileCount : Nat  -- computed

def downloadRegion (region : OfflineRegion) (progress : Nat → Nat → IO Unit) : IO Unit
```

### Route Display

Draw paths/routes on the map:
- Array of lat/lon points
- Configurable line style
- Arrowheads for direction
- Distance calculation

---

## Architecture Improvements

### Abstract Renderer Interface

Currently tied to Afferent/Metal. Abstract for portability:

```lean
class MapRenderer (R : Type) where
  drawTexture : R → Texture → Rect → Rect → Float → IO Unit
  getScreenSize : R → IO (Int × Int)

-- Implementations for Afferent, software rasterizer, etc.
```

### Event System

Add callbacks for map events:

```lean
structure MapEvents where
  onTileLoaded : Option (TileCoord → IO Unit) := none
  onTileError : Option (TileCoord → String → IO Unit) := none
  onViewportChange : Option (MapViewport → IO Unit) := none
  onClick : Option (Float → Float → LatLon → IO Unit) := none
```

### State Monad

Wrap state updates in a dedicated monad:

```lean
abbrev MapM := StateT MapState IO

def handleInputM : MapM Unit := do
  let state ← get
  -- ...
```

---

## Dependencies to Consider

| Feature | Potential Dependency |
|---------|---------------------|
| Vector tiles | New: `mvt-parser` (PBF decoding) |
| GeoJSON | New: `geojson` (JSON parsing exists in workspace) |
| Geocoding | `wisp` (HTTP already available) |
| Route calculations | `linalg` (already in workspace) |

---

## Non-Goals

The following are explicitly out of scope:

- 3D terrain/elevation rendering (use Afferent directly)
- Real-time GPS tracking (application-level concern)
- Full GIS functionality (projection transformations, etc.)
- Tile server implementation (client-side only)

---

## Version Milestones

### v0.2 - Polish ✅ COMPLETED
- [x] Deduplicate utility functions
- [x] Add comprehensive test suite (129 tests)
- [x] Remove debug logging
- [x] Named constants for magic numbers
- [x] Configurable tile provider (13 presets)
- [x] Configurable zoom animation (3 easing types)
- [x] Bounding box constraints (4 preset regions)

### v0.3 - Interactivity ✅ COMPLETED
- [x] Keyboard navigation
- [x] Coordinate display at cursor
- [x] Scale bar
- [x] Tile loading indicator

### v0.4 - Layers (Partial)
- [x] Marker layer
- [ ] Basic GeoJSON support
- [ ] Mini-map

### v0.5 - Performance ✅ COMPLETED
- [x] Predictive prefetching
- [x] Connection pooling
- [x] Request coalescing
- [ ] Texture atlas (deferred - low priority)

### v1.0 - Production Ready
- [ ] Full test coverage
- [ ] Stable API
- [ ] Comprehensive documentation
- [ ] Example applications

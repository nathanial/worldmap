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

Comprehensive test suite with **129 tests** across 7 suites:

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

## Priority 4: New Features

### Keyboard Navigation

Add keyboard controls in `Input.lean`:

| Key | Action |
|-----|--------|
| Arrow keys | Pan map |
| `+` / `=` | Zoom in (centered) |
| `-` | Zoom out (centered) |
| `Home` | Reset to initial view |
| `0`-`9` | Jump to zoom level |

### Coordinate Display

Show lat/lon at cursor position:
- Add `cursorLat`, `cursorLon` fields to `MapState`
- Update in `handleInput`
- Display in overlay (Main.lean)

### Scale Bar

Display a scale indicator showing real-world distance:
- Calculate meters-per-pixel at current zoom/latitude
- Draw a bar with distance label (e.g., "500 m", "1 km")

### Tile Loading Indicator

Show loading progress:
- Count of pending vs loaded tiles
- Optional loading spinner or progress bar
- Event callback when all visible tiles loaded

### Marker/Point Layer

```lean
structure Marker where
  lat : Float
  lon : Float
  label : Option String := none
  color : Color := Color.red
  size : Float := 10.0

structure MarkerLayer where
  markers : Array Marker
  visible : Bool := true
```

Functions:
- `addMarker`, `removeMarker`, `clearMarkers`
- `markersInView` for culling
- `hitTestMarker` for click handling

---

## Priority 5: Performance Optimizations

### Predictive Tile Prefetching

During pan, predict movement direction and prefetch tiles ahead:

```lean
structure PanVelocity where
  dx : Float  -- pixels per frame
  dy : Float

def prefetchAhead (state : MapState) (velocity : PanVelocity) : List TileCoord :=
  -- Predict position 0.5 seconds ahead
  -- Return tiles visible at predicted position that aren't cached
```

### Connection Pooling

The current HTTP implementation creates new connections per request. Add connection pooling to Wisp or use keep-alive connections.

### Texture Atlas

Batch multiple tiles into a single texture atlas for fewer draw calls:
- Pack recently loaded tiles into atlas
- Track atlas position per tile
- Fall back to individual textures when atlas is full

### Request Coalescing

If multiple zoom levels are requested quickly, cancel intermediate requests:
- Track target zoom vs current fetching zoom
- Cancel in-flight requests for zoom levels between

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

### v0.3 - Interactivity
- [ ] Keyboard navigation
- [ ] Coordinate display at cursor
- [ ] Scale bar
- [ ] Tile loading indicator

### v0.4 - Layers
- [ ] Marker layer
- [ ] Basic GeoJSON support
- [ ] Mini-map

### v0.5 - Performance
- [ ] Predictive prefetching
- [ ] Connection pooling
- [ ] Request coalescing

### v1.0 - Production Ready
- [ ] Full test coverage
- [ ] Stable API
- [ ] Comprehensive documentation
- [ ] Example applications

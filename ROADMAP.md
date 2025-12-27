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

## Priority 1: Code Cleanup

### Deduplicate Utility Functions

Several helper functions are duplicated across modules:

| Function | Locations |
|----------|-----------|
| `intToFloat`, `natToInt`, `intMax`, `intMin` | `TileCoord.lean` |
| `floatMax`, `floatMin`, `floatClamp` | `Zoom.lean` |
| `pi` constant | `TileCoord.lean` |

**Action:** Create `Worldmap/Utils.lean` with shared constants and utility functions.

### Remove Debug Logging

- `MapState.init` contains `IO.println` debug output that should be removed or made conditional
- Consider adding a `debug` flag to `MapState` or using a logging library

### Named Constants for Magic Numbers

| Current | Suggested Name |
|---------|----------------|
| `512` (tile size) | Already named in `MapViewport.tileSize` |
| `1500` (max cached images) | `defaultMaxCachedImages` |
| `100 * 1024 * 1024` | `defaultDiskCacheBytes` |
| `0.15` (lerp factor) | Already named as `zoomLerpFactor` |
| `0.01` (snap threshold) | Already named as `zoomSnapThreshold` |
| `85.0` (Mercator latitude limit) | `maxMercatorLatitude` |

---

## Priority 2: Testing

### Add Test Suite

The project currently lacks tests. Add tests using Crucible:

- [ ] **TileCoord tests**
  - `latLonToTile` / `tileToLatLon` round-trip consistency
  - Edge cases: poles, date line, zoom level 0 and 19
  - `parentTile` / `childTiles` relationship

- [ ] **Viewport tests**
  - `visibleTiles` returns correct tile count
  - `pixelsToDegrees` consistency
  - `tileScreenPos` and `centerTilePos` inverse relationship

- [ ] **Zoom tests**
  - `zoomToPoint` keeps anchor point fixed
  - `screenToGeo` / `geoToTile` consistency
  - Latitude clamping and longitude wrapping

- [ ] **RetryLogic tests**
  - Exponential backoff timing
  - `shouldRetry` respects exhaustion
  - State transitions

- [ ] **TileCache tests**
  - State transitions (pending → loaded → cached)
  - LRU eviction order
  - `tilesToUnload` and `staleTiles` logic

### Add `lake test` Target

Add to `lakefile.lean`:
```lean
lean_exe worldmap_tests where
  root := `Tests.Main
  moreLinkArgs := commonLinkArgs

@[test_driver]
lean_exe test where
  root := `Tests.Main
  moreLinkArgs := commonLinkArgs
```

---

## Priority 3: Configuration & Flexibility

### Configurable Tile Provider

Currently hardcoded to CartoDB Dark @2x tiles. Make this configurable:

```lean
structure TileProvider where
  name : String
  urlTemplate : String  -- "{s}.example.com/{z}/{x}/{y}.png"
  subdomains : Array String := #["a", "b", "c", "d"]
  tileSize : Int := 256
  retinaScale : Int := 2  -- 1 for standard, 2 for @2x
  attribution : String := ""
  maxZoom : Int := 19
  deriving Repr, Inhabited
```

**Preset providers:**
- CartoDB Dark/Light/Voyager
- OpenStreetMap standard
- Stamen Terrain/Toner/Watercolor
- Custom URL template

### Configurable Zoom Animation

```lean
structure ZoomAnimationConfig where
  lerpFactor : Float := 0.15
  snapThreshold : Float := 0.01
  easingFunction : EasingType := .linear
  deriving Repr, Inhabited

inductive EasingType where
  | linear | easeOut | easeInOut | custom (f : Float → Float)
```

### Bounding Box Constraints

Allow restricting the viewable area:

```lean
structure MapBounds where
  minLat : Float := -85.0
  maxLat : Float := 85.0
  minLon : Float := -180.0
  maxLon : Float := 180.0
  minZoom : Int := 0
  maxZoom : Int := 19
```

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

### v0.2 - Polish
- [ ] Deduplicate utility functions
- [ ] Add comprehensive test suite
- [ ] Remove debug logging
- [ ] Configurable tile provider

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

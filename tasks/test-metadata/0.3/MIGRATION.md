# Migration Guide: test-metadata 0.2 → 0.3

## Key Changes

### Enhanced Error Handling
- **PR Author Retrieval**: Added `2>/dev/null || echo ""` to prevent silent failures
- **SNAPSHOT Parsing**: All JQ commands now have error handling with fallback to empty string
- **Validation**: Added required `KONFLUX_COMPONENT_NAME` validation

### Prefetch Improvements
- **Always Enabled**: Removed `enable-prefetch` parameter (now always on)
- **Enhanced Support**: Added both CACHI2_ARTIFACT and SOURCE_ARTIFACT support
- **Container Info**: Added container repository and tag extraction

### New Results
- `source-artifact`: Source artifact from prefetch operations
- `container-repo`: Container repository extracted from image
- `container-tag`: Container tag extracted from image

## Breaking Changes
- **Removed**: `enable-prefetch` parameter
- **Removed**: `test-name` parameter

## Migration
1. Remove references to `enable-prefetch` and `test-name` parameters
2. Prefetch is now automatic (no conditional handling needed)
3. Task has better error handling - adjust pipeline error handling if needed 
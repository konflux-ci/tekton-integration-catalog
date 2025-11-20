# Migration Guide: test-metadata 0.3 → 0.4

## Key Changes

### New Results
- `instrumented-container-image`: Container image reference containing the instrumented code
- `instrumented-container-repo`: Container repository extracted from image
- `instrumented-container-tag`: Container tag extracted from image

If the instrumented image is not found, the result will be empty string.
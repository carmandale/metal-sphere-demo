---
trigger: manual
description:
globs:
---
# Metal Optimization

This project follows best practices for Metal performance optimization in visionOS 2.

## Key Files
- [FractalSystem.swift](mdc:MetalSphereDemo/FractalSystem.swift) - Compute system implementation
- [SphereFractal.metal](mdc:MetalSphereDemo/Compute/SphereFractal.metal) - Compute shader

## Texture Management
- Reuse textures between frames rather than reallocating GPU resources
- Use appropriate pixel formats (e.g., `rgba16Float` for HDR content)
- Set proper texture usage flags (`[.shaderRead, .shaderWrite]`) based on needs
- Example: 
```swift
let desc = LowLevelTexture.Descriptor(
    pixelFormat : .rgba16Float,
    width       : texSize,
    height      : texSize,
    textureUsage: [.shaderRead, .shaderWrite]
)
```

## Compute Optimization
- Use compute shaders for parallel workloads like procedural textures
- Minimize CPU-GPU synchronization points
- Batch similar operations to reduce API overhead
- Use Metal Performance Shaders (MPS) for common algorithms when appropriate

## Performance Targets
- Target 90 FPS minimum for comfortable immersive experiences
- Profile with Instruments regularly using the Metal System Trace template
- Minimize shader complexity for spatial experiences

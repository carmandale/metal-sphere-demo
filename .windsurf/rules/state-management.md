---
trigger: model_decision
description: 
globs: 
---
# State Management

This project follows modern state management patterns for SwiftUI in visionOS 2.

## Core Principles
- Use `@Observable` macro for modern state management instead of ObservableObject
- Create dedicated model classes with `@Observable` for sharing state across views
- Leverage derived state with `@Bindable` when passing observable objects to child views
- Use `@State` only for view-local temporary state not needed by other components
- Use the latest `.onChange(of:)` modifier with the current signature that takes both old and new values:
```swift
.onChange(of: value) { oldValue, newValue in
    // Handle state change
}
```

## RealityKit Integration
- Use `@MainActor` for view structs interacting with RealityKit
- Example:
```swift
@MainActor
struct ImmersiveView: View {
    // View implementation
}
```

## SwiftUI UI Elements
- Add UI controls to immersive spaces using `.ornament()` for floating windows
- Use `.glassBackgroundEffect()` for context-appropriate UI blending
- Implement proper preview macros with `#Preview(immersionStyle:)`

## Key Files
- [ImmersiveView.swift](mdc:MetalSphereDemo/ImmersiveView.swift) - Main immersive view implementation

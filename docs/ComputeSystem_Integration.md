# RealityKit Compute System – Integration Guide

Use this document when you need GPU compute power inside a RealityKit scene.  It
explains the small helper layer (`ComputeSystem.swift`, `ComputeUtilities.swift`)
we ship with this repo and shows how to adapt it to your own projects.

> **TL;DR**
>
> * Adopt the `ComputeSystem` protocol in your own renderer.
> * Wrap the instance in `ComputeSystemComponent`.
> * Register a single `ComputeDispatchSystem` once per `Scene`.
> * Write your Metal kernel as usual; the helpers take care of the rest.

---

## 1. File Overview

| File | What it contains | Notes |
|------|------------------|-------|
| `ComputeUtilities.swift` | Convenience helpers for Metal device, command-queue, and pipeline creation. | Import-agnostic; no RealityKit dependency. |
| `ComputeSystem.swift`    | The lightweight abstraction layer on top of RealityKit's entity–component model. Contains<br>• `ComputeUpdateContext`<br>• `ComputeSystem` protocol<br>• `ComputeSystemComponent`<br>• `ComputeDispatchSystem` | Only ~70 lines; easy to inline if you prefer. |

---

## 2. `ComputeUtilities.swift`

```swift
// The system-wide Metal device (picked automatically by Metal)
let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

// A labelled command queue – you'll normally need just one per app.
func makeCommandQueue(labeled label: String) -> MTLCommandQueue? { /* … */ }

// Helper to compile a compute pipeline by name from the default *.metal* library.
func makeComputePipeline(named name: String) -> MTLComputePipelineState? { /* … */ }
```

Nothing exotic here: the helpers just shorten common boilerplate and return
`nil` if something goes wrong (e.g. shader typo).

---

## 3. `ComputeSystem` Architecture

```
┌──────────────┐        ┌────────────────────┐
│  Your Entity │───┐    │ ComputeDispatchSystem │← RealityKit System that
└──────────────┘   │    └────────────────────┘   drives all compute work
                   │             ▲
      components.set()           │
                   ▼             │ update(context:)
         ┌───────────────────────────────┐
         │ ComputeSystemComponent        │ – simple wrapper holding any object
         └───────────────────────────────┘   that conforms to…
                   │
                   ▼
         ┌───────────────────────────────┐
         │      ComputeSystem            │ – your custom renderer, fractal,
         └───────────────────────────────┘   physics sim, etc.
```

### 3.1 `ComputeUpdateContext`
A value-type handed to you every frame containing:
* `deltaTime` – seconds since last frame.
* `commandBuffer` – already enqueued & ready.
* `computeEncoder` – an open encoder to which you append your commands.

### 3.2 `ComputeSystem` Protocol
`@MainActor func update(computeContext: ComputeUpdateContext)`

Conform to this, encode your kernel(s), and you're done.

### 3.3 `ComputeSystemComponent`
An ordinary RealityKit `Component` whose only job is to store your `ComputeSystem`.
Attach it to **any** entity (even an empty placeholder).

### 3.4 `ComputeDispatchSystem`
A custom RealityKit `System` that:
1. Queries the scene for all entities bearing a `ComputeSystemComponent`.
2. Creates **one** command buffer + compute encoder per frame.
3. Calls `update(computeContext:)` on each registered system.
4. Ends encoding and commits.

You must register this once per scene:
```swift
scene.addSystem(ComputeDispatchSystem.init) // RealityKit 2.5+
```

---

## 4. Quick-Start Example

```swift
// 1. Build your compute renderer (e.g. a reaction-diffusion sim)
final class MySim: ComputeSystem {
    private let pipeline: MTLComputePipelineState = makeComputePipeline(named: "myKernel")!
    func update(computeContext ctx: ComputeUpdateContext) {
        let enc = ctx.computeEncoder
        enc.setComputePipelineState(pipeline)
        // bind textures/buffers…
        enc.dispatchThreadgroups(/* … */)
    }
}

// 2. Scene setup
let sim = MySim()

let driver = Entity()
driver.components.set(ComputeSystemComponent(computeSystem: sim))
scene.addAnchor(driver)

scene.addSystem(ComputeDispatchSystem.init) // only once
```

No manual command-queue juggling, no subscription to `SceneEvents.Update`.

---

## 5. Tips & Gotchas

| Tip | Why it matters |
|-----|---------------|
| **One command buffer per frame** – Provided by `ComputeDispatchSystem`; avoid making your own inside `update` unless absolutely needed. |
| **Keep workgroup sizes consistent** – RealityKit doesn't enforce this but GPUs prefer powers-of-two (e.g. 16 × 16). |
| **Textures need `shaderRead` & `shaderWrite`** usage** | Otherwise you'll get runtime warnings or black output. |
| **Remember to advance your own time uniform** | `ComputeUpdateContext` gives `deltaTime`; accumulate it in your renderer. |

---

## 6. Integrating `ProceduralTextureRenderer`
If you want animated sphere textures exactly like the demo:

```swift
let renderer = ProceduralTextureRenderer(effect: .tunnel)

let driver = Entity()
driver.components.set(ComputeSystemComponent(computeSystem: renderer))
scene.addAnchor(driver)

let sphere = ModelEntity(mesh: .generateSphere(radius: 0.4))
var mat = UnlitMaterial(texture: renderer.textureResource)
sphere.model?.materials = [mat]
scene.addAnchor(AnchorEntity(world: .zero, children: [sphere]))
```

That's the entire public API.

---

## 7. Porting to an Existing Project
1. Copy **`ComputeUtilities.swift`** and **`ComputeSystem.swift`** into your target.
2. Add your own `ComputeSystem` implementation(s).
3. Register **one** `ComputeDispatchSystem` before your scene starts rendering.
4. Profit 🍹.

---

© 2024 — Feel free to reuse / modify; no warranty. 
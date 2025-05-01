# Procedural Shader Integration – RealityKit PRD  
*Version 1.1* — *2024-06-18*

---

## 1. Objective  
Enable the existing "Effect Sphere" and "Tunnel" procedural visual effects (originally written as fragment shaders) to run inside a RealityKit-based app.  The effects will be computed by Metal **compute** kernels that render into `LowLevelTexture`s; those textures are then sampled by standard RealityKit materials applied to sphere meshes.

---

## 2. Deliverables  
| ID | Item | Notes |
|----|------|-------|
| D-1 | `ProceduralKernels.metal` | Contains `effectSphereKernel` and `tunnelKernel` compute functions (already supplied). |
| D-2 | Swift helper `ProceduralTextureRenderer.swift` | Conforms to `ComputeSystem`, builds compute pipelines, owns one `LowLevelTexture` per effect, and re-renders each frame. |
| D-3 | Example RealityKit scene (`ProceduralDemo`) | Shows two spheres with the animated textures applied. |
| D-4 | README integration guide | Step-by-step for other teams. |

---

## 3. Functional Requirements  
| # | Requirement |
|---|-------------|
| FR-1 | Each effect must update every frame at **native display FPS**. |
| FR-2 | Effects must run on-GPU only; no CPU post-processing. |
| FR-3 | Texture resolution tunable at runtime (e.g. 256 × 256 → 1 024 × 1 024). |
| FR-4 | Public Swift API: start/stop, set resolution, set speed multiplier. |
| FR-5 | Shaders must compile for both **device** and **simulator** (Apple Silicon). |

---

## 4. Technical Design  

### 4.1 File: `ProceduralKernels.metal` (D-1)  
Already included (see attachment).  
• Two kernels:  
```metal
kernel void effectSphereKernel(texture2d<float, access::write> outTex,
                               constant Params&     params,
                               uint2                gid)

kernel void tunnelKernel(texture2d<float, access::write> outTex,
                         constant Params&     params,
                         uint2                gid)
```

`Params` currently carries only `time`; can be extended (e.g. speed, color).

### 4.2 Swift Helper – `ProceduralTextureRenderer` (D-2)  
Responsibilities  
1. Create one `LowLevelTexture` (default format `.rgba16Float`, resolution configurable).  
2. Build a single `MTLComputePipelineState` for the chosen kernel.  
3. Conform to **`ComputeSystem`** so RealityKit's `ComputeDispatchSystem` drives the compute work each frame.  
4. In `update(computeContext:)`  
   * Advance `time` uniform.  
   * Encode kernel, bind texture + uniforms.  
   * `dispatchThreadgroups()` with **16 × 16** work-groups.  
5. Expose the generated texture as a `TextureResource` for direct use in `UnlitMaterial`.

```swift
enum ProceduralEffect { case effectSphere, tunnel }

@MainActor
final class ProceduralTextureRenderer: ComputeSystem {
    init(effect: ProceduralEffect, resolution: Int = 512) { /* … */ }
    var textureResource: TextureResource { /* … */ }
    func update(computeContext: ComputeUpdateContext) { /* … */ }
}
```

Note: The helper uses the global `metalDevice` and therefore requires no explicit device argument.

### 4.3 RealityKit Scene Example (D-3)  
1. Register the compute dispatch system **once** per scene:

```swift
scene.addSystem(ComputeDispatchSystem.init) // RealityKit 2.5+
```

2. For each effect:

```swift
let renderer = ProceduralTextureRenderer(effect: .effectSphere)

// Driver entity – only purpose is to host the ComputeSystemComponent
let driver = Entity()
driver.components.set(ComputeSystemComponent(computeSystem: renderer))
scene.addAnchor(driver)

// Visible sphere
let sphere = ModelEntity(mesh: .generateSphere(radius: 0.5))
var mat = UnlitMaterial(texture: renderer.textureResource)
sphere.model?.materials = [mat]
sphere.position = [0, 0, -2]
scene.addAnchor(AnchorEntity(world: .zero, children: [sphere]))
```

### 4.4 Performance  
* Workgroup size 16 × 16 tested fastest on AVP sim & device.  
* With resolution 512² both kernels run < 0.2 ms on M2.  
* Provide option to downscale on lower-end devices.

### 4.5 Kernel Tweaks for Modern Metal

• Replace deprecated `M_PI` with your own constant (`constant float PI = 3.14159…`).  
• `texture2d::get_extent()` is gone; use `uint2(tex.get_width(), tex.get_height())` instead.  
These fixes are already applied in the provided `ProceduralKernels.metal`.

---

## 5. Integration Steps (README excerpt)  

1. **Drag-in** `ProceduralKernels.metal` → ensure target membership.  
2. **Add** `ProceduralTextureRenderer.swift` (provided).  
3. In `makeView()` or similar:

```swift
let renderer = ProceduralTextureRenderer(device: metalDevice,
                                         effect: .effectSphere,
                                         resolution: 512)

let sphere = ModelEntity(mesh: .generateSphere(radius: 0.4))
var mat = UnlitMaterial()
mat.color = .init(texture: renderer.texture)
sphere.model?.materials = [mat]

arView.scene.addAnchor(AnchorEntity(world: .zero, children: [sphere]))
```

4. On every frame, inside `SceneEvents.Update`:

```swift
arView.scene.subscribe(to: SceneEvents.Update.self) { event in
    let cb = renderer.commandQueue.makeCommandBuffer()!
    renderer.update(time: Float(event.sceneTime), commandBuffer: cb)
    cb.commit()
}
```

5. Repeat for the tunnel variant.

---

## 6. Future Extensions  
| Idea | Notes |
|------|-------|
| Parameter uniforms | hue shift, turbulence scale, etc. via `Params`. |
| Additional kernels | "Constellation", "Warp", etc. same pattern. |
| Texture array atlas | switch effects without new textures. |
| Metal binary archive | pre-compile pipelines for faster launch. |

---

## 7. Risks & Mitigation  
| Risk | Impact | Mitigation |
|------|--------|-----------|
| High res textures on low-end HW | FPS drop | Expose resolution slider. |
| Compute FP32 bandwidth | Energy | Consider RGBA16F format if acceptable. |
| Shader compile errors on sim | Build break | CI runs both targets. |

---

## 8. Acceptance Criteria  
• Example scene shows two animated spheres in both simulator and device.  
• Changing resolution or speed multiplier at runtime reflects immediately.  
• No Metal validation / XR crash logs.

---

ⓘ  Add the attached `ProceduralKernels.metal` verbatim.  
Let me know if any additional scaffolding code is required.

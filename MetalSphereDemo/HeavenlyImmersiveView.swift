import SwiftUI
import RealityKit
import Metal
import RealityKitContent

/// Immersive scene that loads `HeavenlyImmersive.usda`, finds the `HeavenlySphere`
/// entity and drives its material with the `heavenlyKernel` compute shader.
@MainActor
struct HeavenlyImmersiveView: View {

    // MARK: – Constants & GPU helpers
    private let texSize = 512
    private let renderer: ProceduralTextureRenderer

    // MARK: – UI-driven uniforms
    @State private var intensity: Float = 2.0  // HDR gain 1‥10

    // Keep a handle to swap material
    @State private var sphere: ModelEntity?

    // MARK: Init
    init() {
        renderer = ProceduralTextureRenderer(effect: .effectSphere,
                                             resolution: texSize)
    }

    // MARK: – View body
    var body: some View {
        RealityView { content, attachments async in
            // -----------------------------------------------------------------
            // 0) Register compute system entity
            // -----------------------------------------------------------------
            let sysEnt = Entity()
            sysEnt.components.set(ComputeSystemComponent(computeSystem: renderer))
            content.add(sysEnt)

            // -----------------------------------------------------------------
            // 1) Load the Reality Composer asset asynchronously
            // -----------------------------------------------------------------
            let assetRoot = try! await Entity(named: "HeavenlyImmersive", in: realityKitContentBundle)
            content.add(assetRoot)

            if let s = assetRoot.findEntity(named: "HeavenlySphere") as? ModelEntity {
                sphere = s

                let texRes = renderer.textureResource
                var pDesc = UnlitMaterial.Program.Descriptor()
                pDesc.blendMode = .add
                let program = await UnlitMaterial.Program(descriptor: pDesc)

                var mat = UnlitMaterial(program: program)
                mat.color = .init(texture: .init(texRes))
                mat.blending = .transparent(opacity: 1.0)

                s.model?.materials = [mat]
            }

            // -----------------------------------------------------------------
            // 2) Attachments – slider panel
            // -----------------------------------------------------------------
            if let sliderEnt = attachments.entity(for: "navSlider") {
                sliderEnt.position = SIMD3<Float>(-0.5, 1.5, -0.5)
                content.add(sliderEnt)
            }

        } update: { _, _ in
            /* No per-frame Swift work needed */
        } attachments: {
            Attachment(id: "navSlider") {
                VStack {
                    Spacer()
                    VStack {
                        Text("Intensity: \(String(format: "%.1f", intensity))")
                        Slider(value: $intensity, in: 1...10, step: 0.1)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 300)
                    .padding(.bottom, 40)
                }
            }
        }
        // Build additive material once view appears
        .task {
            updateUniforms()
        }
        .onChange(of: intensity) { updateUniforms() }
    }

    // MARK: Uniform push
    private func updateUniforms() {
        renderer.setIntensity(intensity)
    }
} 

import SwiftUI
import RealityKit
import Metal

@MainActor
struct ImmersiveView: View {
    // MARK: – Stored state -------------------------------------------------
    private let texSize = 512
    private let fractalTex: LowLevelTexture
    private let fractalSystem: FractalSystem
    private let effectRenderer: ProceduralTextureRenderer
    private let tunnelRenderer: ProceduralTextureRenderer

    @State private var sphere   : ModelEntity?        // handle we can mutate
    @State private var material = UnlitMaterial()     // placeholder
    
    // -------------------------------------------------------------------------
    // 1. State vars for the sliders
    // -------------------------------------------------------------------------
    @State private var intensity: Float = 2.2   // HDR gain 1‥10
    @State private var jitter: Float = 0.0   // 0‥1  (0 = old behaviour)
    @State private var density: Float = 0.0    // 0‥1
    @State private var amount: Float = 1     // 1‥5  (whole numbers look best)
    
    @State private var showSliderToggle: Bool = true

    // MARK: – Init (sync) --------------------------------------------------
    init() {
        // low-level texture
        let desc = LowLevelTexture.Descriptor(
            pixelFormat : .rgba16Float,
            width       : texSize,
            height      : texSize,
            textureUsage: [.shaderRead, .shaderWrite]
        )
        fractalTex    = try! LowLevelTexture(descriptor: desc)

        // compute system
        fractalSystem = FractalSystem(
            texture: fractalTex,
            width  : texSize,
            height : texSize
        )

        // procedural renderers
        effectRenderer = ProceduralTextureRenderer(effect: .effectSphere)
        tunnelRenderer = ProceduralTextureRenderer(effect: .tunnel)
    }

    // MARK: – View body ----------------------------------------------------
    var body: some View {
        RealityView { content, attachments in
            // 1) compute system entity
            let sys = Entity()
            sys.components.set(
                ComputeSystemComponent(computeSystem: fractalSystem)
            )
            content.add(sys)
            
            // 2) sphere with *temporary* material
            let s = ModelEntity(
                mesh: .generateSphere(radius: 0.5),
                materials: [material]
            )
            s.position = [0, 1.5, -2]
            content.add(s)
            sphere = s
            
            if showSliderToggle {
                if let navEnt = attachments.entity(for: "navSlider") {
//                    navEnt.components[BillboardComponent.self] = .init()
                    navEnt.scale = .one // SIMD3<Float>(0.45, 0.45, 0.45)
                    navEnt.position = SIMD3<Float>(-0.5, 1.5, -0.5)
                    content.add(navEnt)
                }
            }// keep reference
            
            let texRes = try! TextureResource(from: fractalTex)
            let effectRes = effectRenderer.textureResource
            let tunnelRes = tunnelRenderer.textureResource

            var mat = UnlitMaterial(texture: texRes)
            var effectMat = UnlitMaterial(texture: effectRes)
            var tunnelMat = UnlitMaterial(texture: tunnelRes)

            content.add(s)

            let effectSphere = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [effectMat])
            effectSphere.transform.translation = [-1.2, 0, -2]
            content.add(effectSphere)

            let tunnelSphere = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [tunnelMat])
            tunnelSphere.transform.translation = [1.2, 0, -2]
            content.add(tunnelSphere)

            // Compute system driver entities
            let effEntity = Entity()
            effEntity.components.set(ComputeSystemComponent(computeSystem: effectRenderer))
            content.add(effEntity)

            let tunEntity = Entity()
            tunEntity.components.set(ComputeSystemComponent(computeSystem: tunnelRenderer))
            content.add(tunEntity)
        } update: { _, attachments in
            /* no per-frame work needed */
        } attachments: {
            // always build it once
            Attachment(id: "navSlider") {
                VStack {
                    Spacer()
                    VStack {
                        Text("Intensity: \(String(format: "%.1f", intensity))")
                        Slider(value: $intensity, in: 1...10, step: 0.1)
                        
                        Text("Jitter \(String(format: "%.2f", jitter))")
                        Slider(value: $jitter, in: 0...0.3, step: 0.01)   // clamped
                        
                        Text("Dot Density \(String(format: "%.2f", density))")
                        Slider(value: $density, in: 0...1, step: 0.01)
                        
                        Text("Dot Amount \(amount, format: .number.precision(.fractionLength(0)))")
                        Slider(value: $amount, in: 1...5, step: 1)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 300)
                    .padding(.bottom, 40)
                }
            }
        }
        // 3) build additive material once the view appears
        .task {
            let newMat = await makeAdditiveMaterial()
            material   = newMat                 // updates SwiftUI state
            sphere?.model?.materials = [newMat] // swaps material ONCE
            updateUniforms()               // send initial values
        }
        // -------------------------------------------------------------------------
        // 3. Send the values to the compute system each frame
        // -------------------------------------------------------------------------
        .onChange(of: intensity) { updateUniforms() }
        .onChange(of: jitter)    { updateUniforms() }
        .onChange(of: density)   { updateUniforms() }
        .onChange(of: amount)    { updateUniforms() }   
    }

    // MARK: – Helper to compile additive program --------------------------
    @MainActor
    private func makeAdditiveMaterial() async -> UnlitMaterial {
        let texRes = try! await TextureResource(from: fractalTex)

        var pDesc = UnlitMaterial.Program.Descriptor()
        pDesc.blendMode = .add                      // additive GPU pipeline

        let prog = try! await UnlitMaterial.Program(descriptor: pDesc)

        var mat  = UnlitMaterial(program: prog)
        mat.color      = .init(texture: .init(texRes))
        mat.blending   = .transparent(opacity: 1.0) // runtime flag

        return mat
    }
    
    // MARK: – Push slider changes into the compute system
    @MainActor
    private func updateUniforms() {
        fractalSystem.setParameters(intensity: intensity, jitter: jitter, density: density, amount: amount)
    }
}

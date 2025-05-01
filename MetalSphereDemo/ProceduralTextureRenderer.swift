import RealityKit
import Metal

/// Swift-side mirror of the Metal `Params` struct.
private struct Params { var time: Float }

/// Which kernel to run.
enum ProceduralEffect {
    case effectSphere
    case tunnel

    /// Returns the Metal kernel function name.
    var kernelName: String {
        switch self {
        case .effectSphere: return "effectSphereKernel"
        case .tunnel:       return "tunnelKernel"
        }
    }
}

/// Drives one `LowLevelTexture` by repeatedly dispatching a compute kernel each frame.
@MainActor
final class ProceduralTextureRenderer: ComputeSystem {

    // MARK: Stored properties
    let texture: LowLevelTexture
    private let pipeline: MTLComputePipelineState
    private let uniformBuffer: MTLBuffer
    private var uniforms = Params(time: 0)

    private let threadsPerTG = MTLSize(width: 16, height: 16, depth: 1)
    private let threadgroups : MTLSize

    // MARK: Init
    init(effect: ProceduralEffect, resolution: Int = 512) {
        // 1. Create the destination texture
        let desc = LowLevelTexture.Descriptor(pixelFormat : .rgba16Float,
                                              width       : resolution,
                                              height      : resolution,
                                              textureUsage: [.shaderRead, .shaderWrite])
        texture = try! LowLevelTexture(descriptor: desc)

        // 2. Build compute pipeline
        guard let pipeline = makeComputePipeline(named: effect.kernelName) else {
            fatalError("Failed to create compute pipeline for \(effect.kernelName)")
        }
        self.pipeline = pipeline

        // 3. Uniform buffer
        uniformBuffer = metalDevice!.makeBuffer(length : MemoryLayout<Params>.stride,
                                                options: .storageModeShared)!

        // 4. Threadgroup sizes
        threadgroups = MTLSize(width : (resolution + threadsPerTG.width  - 1) / threadsPerTG.width,
                               height: (resolution + threadsPerTG.height - 1) / threadsPerTG.height,
                               depth : 1)
    }

    // Convenience: RealityKit `TextureResource` for this texture.
    var textureResource: TextureResource { try! TextureResource(from: texture) }

    // MARK: - ComputeSystem
    func update(computeContext: ComputeUpdateContext) {
        // Advance time
        uniforms.time += Float(computeContext.deltaTime)
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Params>.stride)

        // Encode
        let encoder = computeContext.computeEncoder
        encoder.setComputePipelineState(pipeline)
        let writeTex = texture.replace(using: computeContext.commandBuffer)
        encoder.setTexture(writeTex, index: 0)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerTG)
    }
} 
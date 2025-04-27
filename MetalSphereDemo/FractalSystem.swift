//
//  FractalSystem.swift
//  MetalSphereDemo (visionOS 2.5 β3)
//
//  Uses Apple’s ComputeSystem helpers.
//

import RealityKit
import Metal

/// Must match `FractalUniforms` in SphereFractal.metal
struct FractalUniforms { var time: Float }

@MainActor
class FractalSystem: ComputeSystem {

    // MARK: stored
    private let texture        : LowLevelTexture
    private let pipeline       : MTLComputePipelineState
    private let uniformBuffer  : MTLBuffer
    private var uniforms       = FractalUniforms(time: 0)

    private let threadsPerTG   = MTLSize(width: 8, height: 8, depth: 1)
    private let threadgroups   : MTLSize

    // MARK: init
    init(texture: LowLevelTexture, width: Int, height: Int) {
        self.texture  = texture
        self.pipeline = makeComputePipeline(named: "sphereFractal2D")!

        self.uniformBuffer = metalDevice!.makeBuffer(
            length : MemoryLayout<FractalUniforms>.stride,
            options: .storageModeShared)!

        self.threadgroups = MTLSize(width : (width  + 7) / 8,
                                    height: (height + 7) / 8,
                                    depth : 1)
    }

    // MARK: ComputeSystem
    func update(computeContext: ComputeUpdateContext) {
        // 1. advance time
        uniforms.time += Float(computeContext.deltaTime)
        memcpy(uniformBuffer.contents(),
               &uniforms,
               MemoryLayout<FractalUniforms>.stride)

        // 2. encode kernel
        let encoder = computeContext.computeEncoder
        encoder.setComputePipelineState(pipeline)

        // writable texture for this frame
        let writeTex = texture.replace(using: computeContext.commandBuffer)
        encoder.setTexture(writeTex, index: 0)
        encoder.setBuffer (uniformBuffer, offset: 0, index: 0)

        encoder.dispatchThreadgroups(threadgroups,
                                     threadsPerThreadgroup: threadsPerTG)
    }
}

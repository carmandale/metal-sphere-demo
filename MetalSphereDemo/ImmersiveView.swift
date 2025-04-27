//
//  ImmersiveView.swift
//  MetalSphereDemo   • visionOS 2.5 β3
//

import SwiftUI
import RealityKit
import Metal    // for MTLDevice, MTLTextureUsage

@MainActor
struct ImmersiveView: View {
    // 1) Texture size
    private let texSize = 512

    // 2) One‐time setup in init
    private let fractalTex: LowLevelTexture
    private let fractalSystem: FractalSystem
    private let material: UnlitMaterial

    init() {
        // 2a) Describe and allocate the GPU texture
        let desc = LowLevelTexture.Descriptor(
            pixelFormat : .rgba16Float,
            width       : texSize,
            height      : texSize,
            textureUsage: [.shaderRead, .shaderWrite]
        )
        fractalTex = try! LowLevelTexture(descriptor: desc)

        // 2b) Build the compute system that overwrites fractalTex each frame
        fractalSystem = FractalSystem(
            texture: fractalTex,
            width  : texSize,
            height : texSize
        )

        // 2c) Wrap the LowLevelTexture in a TextureResource
        let texRes = try! TextureResource(from: fractalTex)

        // 2d) **Apple pattern**: create an UnlitMaterial with that resource
        var mat = UnlitMaterial(texture: texRes)
//        mat.opacityThreshold = 0.0
        material = mat
    }

    var body: some View {
        RealityView { content in
            // 3) Register compute system (Apple’s ComputeSystemComponent)
            let sysEntity = Entity()
            sysEntity.components.set(
                ComputeSystemComponent(computeSystem: fractalSystem)
            )
            content.add(sysEntity)
            
//            let testMaterial = SimpleMaterial(color: .red, isMetallic: false)
            

            // 4) Create *one* sphere with our pre‐built material
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.5),
                materials: [ material ]      // <— Apple’s UnlitMaterial(texture:)
            )
            sphere.transform.translation = [0, 0, -2]  // 1 m in front
            content.add(sphere)

        } update: { _ in
            // 5) **Empty.** Your FractalSystem runs every frame and writes
            //     into the same LowLevelTexture under the hood, and your
            //     UnlitMaterial(texture:) will automatically sample its
            //     updated content. No per‐frame material changes needed.
        }
    }
}

#Preview(immersionStyle: .mixed) { ImmersiveView() }

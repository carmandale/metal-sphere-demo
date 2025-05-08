//
//  MetalSphereDemoApp.swift
//  MetalSphereDemo
//
//  Created by Dale Carman on 4/26/25.
//

import SwiftUI

@main
struct MetalSphereDemoApp: App {

    @State private var appModel = AppModel()

    init() {
        print("MetalSphereDemoApp init")
        ComputeSystemComponent.registerComponent()
        ComputeDispatchSystem.registerSystem()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            HeavenlyImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

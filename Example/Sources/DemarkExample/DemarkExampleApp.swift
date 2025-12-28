//
// DemarkExampleApp.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import SwiftUI

@main
struct DemarkExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(minWidth: 900, idealWidth: 1_200, minHeight: 600, idealHeight: 800)
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}

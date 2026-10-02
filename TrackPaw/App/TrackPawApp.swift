//
//  TrackPawApp.swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-03-25.
//

import CoreData
import SwiftUI
import os

@main
struct TrackPawApp: App {
    @StateObject private var syncMonitor = SyncMonitor()
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    private let persistentContainer: NSPersistentContainer = {
        #if DEBUG && !InitializeCloudKitSchema
        if ProcessInfo.processInfo.arguments.contains("-SNAPSHOT") {
            return PersistenceController.forSnapshotTesting()
        }
        #endif
        return PersistenceController.shared.persistentContainer
    }()

    @ObservedObject var environment = AppEnvironment.shared
    @ObservedObject var coordinator = ViewCoordinator()

    init() {
        CLLocationArrayTransformer.register()
        configureNavigationTitleColor()
        #if DEBUG
            let paths = NSSearchPathForDirectoriesInDomains(
                FileManager.SearchPathDirectory.documentDirectory,
                FileManager.SearchPathDomainMask.userDomainMask,
                true
            )
            Logger.trackPawApp.debug("Path to device content \(paths[0])")
        #endif
    }

    /// Renders navigation titles in the app's light text color while keeping the
    /// iOS 26 Liquid Glass bar. Uses `configureWithDefaultBackground()` (the system
    /// default background, which is Liquid Glass) so only the title color changes —
    /// unlike a transparent+solid-color config, which would flatten the glass.
    private func configureNavigationTitleColor() {
        let titleColor = UIColor(named: "TrackPaw/text-primary") ?? .white
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        #if InitializeCloudKitSchema
            WindowGroup {
                Text("Initializing CloudKit Schema...").font(.title)
                Text(
                    "Stop after Xcode says 'no more requests to execute', "
                        + "then check with CloudKit Console if the schema is created correctly."
                ).padding()
            }
        #else
            WindowGroup {
                MainTabView()
                    .environment(
                        \.managedObjectContext,
                        persistentContainer.viewContext
                    )
                    .environment(\.preferredColorPalette, environment.palette)
                    .environmentObject(environment)
                    .environmentObject(coordinator)
                    .environmentObject(syncMonitor)
                    .onChange(of: coordinator.path) { _, newValue in
                        Logger.trackPawApp.debug(
                            "Coordinator changed path count:\(newValue.count)"
                        )
                    }
            }
        #endif
    }
}

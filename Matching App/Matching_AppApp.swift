//
//  Matching_AppApp.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/29.
//

import SwiftUI

@main
struct Matching_AppApp: App {
    @StateObject var auth = AuthManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // AsyncImageで読み込むプロフィール写真・アイコン等がディスクにキャッシュされるようにする(デフォルトは小さめ)。
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            if auth.isAuthenticated {
                RootGateView()
            } else {
             AuthView()
            }
        }
        .environmentObject(auth)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && auth.isAuthenticated {
                Task { await auth.touchLastActive() }
            }
        }
    }
}

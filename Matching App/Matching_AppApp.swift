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
    /// 初回起動時だけウェルカム画面を出すためのフラグ(端末に永続化される)。
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    init() {
        // AsyncImageで読み込むプロフィール写真・アイコン等がディスクにキャッシュされるようにする(デフォルトは小さめ)。
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenWelcome {
                    WelcomeOnboardingView { hasSeenWelcome = true }
                } else if auth.isRestoringSession {
                    // 保存済みセッションの確認が終わる前に分岐すると、ログイン済みでも
                    // 一瞬ログイン画面が差し込まれてしまうため、確認が終わるまで待つ。
                    SplashView()
                } else if auth.isAuthenticated {
                    RootGateView()
                } else {
                    AuthView()
                }
            }
            // アプリ全体の既定の色みをブランドカラーに統一する。これを設定していないと、
            // 個別にtintを指定していない標準コントロール(誕生日・身長ピッカーの「決定」ボタンなど)が
            // iOS標準の青色のまま表示されてしまい、他の画面の紫基調のデザインから浮いてしまう。
            .tint(Color.brandPurple)
        }
        .environmentObject(auth)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && auth.isAuthenticated {
                Task { await auth.touchLastActive() }
            }
        }
    }
}

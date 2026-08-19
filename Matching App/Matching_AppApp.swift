//
//  Matching_AppApp.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/29.
//

import SwiftUI

/// アプリ内から表示言語を選べるようにするための設定。
/// マイページ、およびウェルカム画面・ログイン画面からもいつでも切り替えられる。
/// 初期状態は「システムに従う」。これはプロジェクトの開発言語(developmentRegion)を
/// 日本語に設定してあるため、日本語の端末では確実に日本語が表示され、英語の端末では
/// 英語(未翻訳の文言は日本語にフォールバック)になる、という国際化として自然な挙動になる。
/// 以前は「システムに従う」がデフォルトだと英語の端末で意図せず英語表記になる不具合があったが、
/// それはdevelopmentRegionの設定ミスが原因だったため、そちらを直した上でこの既定値に戻している。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "システムに従う / System"
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }

    /// nilを返すとSwiftUIは端末の言語設定をそのまま使う。
    var locale: Locale? {
        switch self {
        case .system: return nil
        case .japanese: return Locale(identifier: "ja")
        case .english: return Locale(identifier: "en")
        }
    }
}

@main
struct Matching_AppApp: App {
    @StateObject var auth = AuthManager()
    @Environment(\.scenePhase) private var scenePhase
    /// 初回起動時だけウェルカム画面を出すためのフラグ(端末に永続化される)。
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

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
                } else if let pendingEmail = auth.pendingVerificationEmail {
                    // 登録は受け付けたが、まだメールアドレスの本人確認が済んでいない状態。
                    NavigationStack {
                        EmailVerificationView(email: pendingEmail)
                    }
                } else {
                    AuthView()
                }
            }
            // アプリ全体の既定の色みをブランドカラーに統一する。これを設定していないと、
            // 個別にtintを指定していない標準コントロール(誕生日・身長ピッカーの「決定」ボタンなど)が
            // iOS標準の青色のまま表示されてしまい、他の画面の紫基調のデザインから浮いてしまう。
            .tint(Color.brandPurple)
            .environment(\.locale, (AppLanguage(rawValue: appLanguageRaw) ?? .system).locale ?? Locale.autoupdatingCurrent)
        }
        .environmentObject(auth)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && auth.isAuthenticated {
                Task { await auth.touchLastActive() }
            }
        }
    }
}

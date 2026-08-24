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

extension String {
    /// `String(localized:)`は`@Environment(\.locale)`(アプリ内の「Language」設定)を見ず、
    /// 端末本体のシステム言語だけを見て解決してしまう。そのため、Viewの外(モデルや
    /// ヘルパー関数)で文言を組み立てる際にそのまま使うと、マイページの「Language」で
    /// Englishに切り替えても端末が日本語のままだと日本語で表示され続けてしまっていた
    /// (`String(localized:locale:)`にlocaleを明示しても解決されなかったため、
    /// より枯れた`Bundle.localizedString(forKey:value:table:)`に切り替えている)。
    ///
    /// keyはLocalizable.xcstringsの原文(日本語)キーそのもの。%@ / %lld 等の書式指定を
    /// 含む場合はargsに実引数を渡す(String(format:)と同じ規約)。
    static func appLocalized(_ key: String, _ args: CVarArg...) -> String {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        let bundle: Bundle
        if let identifier = AppLanguage(rawValue: raw)?.locale?.identifier,
           let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
           let localeBundle = Bundle(path: path) {
            bundle = localeBundle
        } else {
            bundle = .main
        }
        let format = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        return args.isEmpty ? format : String(format: format, arguments: args)
    }
}

@main
struct Matching_AppApp: App {
    // APNsのデバイストークン受信コールバックはSwiftUIのApp protocol単体では受け取れないため、
    // UIApplicationDelegateAdaptor経由でAppDelegateを差し込んでいる。
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            // 通知許可のタイミングでまだログインしていなかった場合に備え、
            // ログイン(またはセッション復元)が確定した時点で改めてトークンを紐付け直す。
            if isAuthenticated {
                Task { await PushTokenManager.registerPendingTokenIfNeeded() }
            }
        }
    }
}

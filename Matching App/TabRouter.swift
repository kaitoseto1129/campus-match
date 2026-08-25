//
//  TabRouter.swift
//  Matching App
//

import Foundation
import Combine

enum AppTab {
    case discover, gatherings, likes, chat, myPage
}

/// プッシュ通知のペイロードに含める種別。通知をタップした時、どのタブへ連れて行くべきかの
/// 判断に使う(以前は通知をタップしても最後に開いていたタブのままで、何も起きなかった)。
enum PushNotificationType: String, Codable {
    case like, match, message, gathering

    var destinationTab: AppTab {
        switch self {
        case .like: return .likes
        case .match, .message: return .chat
        case .gathering: return .gatherings
        }
    }
}

/// AppDelegate(SwiftUIのViewツリーの外)が、通知タップで届いた行き先タブを
/// MainTabView(TabRouterの実体を持つ側)へ伝えるための橋渡し役。
/// TabRouter自体はMainTabViewの@StateObjectとして作られ、AppDelegateから直接触れないため、
/// この軽量なシングルトンを経由する。
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    private init() {}
    @Published var pendingTab: AppTab?
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .discover
    /// プッシュされた詳細画面(プロフィール・チャット等)を表示中はtrueにして、
    /// カスタムタブバーがそれらの下部コンテンツ(いいねボタン・入力欄)を隠さないようにする。
    /// 複数の詳細画面が同時にマウントされるケース(スワイプ式プロフィール等)に対応するため、
    /// 単純なBoolではなくカウンタで管理する。
    @Published private(set) var isTabBarHidden = false
    private var hideRequestCount = 0

    /// タブごとの「ルートまで戻れ」信号。値が変わるたびに各タブのNavigationStackがpathを空にする。
    @Published private(set) var popToRootTokens: [AppTab: UUID] = [:]

    func pushDetailScreen() {
        hideRequestCount += 1
        isTabBarHidden = hideRequestCount > 0
    }

    func popDetailScreen() {
        hideRequestCount = max(0, hideRequestCount - 1)
        isTabBarHidden = hideRequestCount > 0
    }

    /// タブバーのボタンから呼ぶ。既に選択中のタブを再度タップした場合は、
    /// そのタブのNavigationStackをルートまで戻す(サブ画面を開いたままタブが反応しない不具合の修正)。
    func selectTab(_ tab: AppTab) {
        if selectedTab == tab {
            popToRootTokens[tab] = UUID()
        } else {
            selectedTab = tab
        }
    }
}

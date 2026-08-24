//
//  TabRouter.swift
//  Matching App
//

import Foundation
import Combine

enum AppTab {
    case discover, gatherings, likes, chat, myPage
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

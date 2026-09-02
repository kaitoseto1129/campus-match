//
//  MainTabView.swift
//  Matching App
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var matchManager = MatchManager()
    @StateObject private var notificationManager = NotificationCenterManager()

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch tabRouter.selectedTab {
                case .discover:
                    DiscoverView()
                case .gatherings:
                    GatheringListView()
                case .chat:
                    ChatListView()
                case .myPage:
                    MyPageHomeView()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !tabRouter.isTabBarHidden {
                    customTabBar
                }
            }

            if let toast = notificationManager.activeToast {
                MessageToastView(toast: toast) {
                    notificationManager.activeToast = nil
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35), value: notificationManager.activeToast?.id)
        .task {
            // 通知タップでアプリがコールド起動された場合、AppDelegateがpendingTabを
            // セットするのはMainTabViewがまだマウントされる前のことがある。
            // .onReceiveは購読開始後の変化しか拾えないため、起動時にも一度直接確認する。
            if let tab = NotificationRouter.shared.pendingTab {
                tabRouter.selectTab(tab)
                NotificationRouter.shared.pendingTab = nil
            }
            await matchManager.start()
            await notificationManager.start()
        }
        .onDisappear {
            Task {
                await matchManager.stop()
                await notificationManager.stop()
            }
        }
        .fullScreenCover(item: $matchManager.celebratingMatch) { celebration in
            MatchCelebrationView(
                myPhotoURL: matchManager.myPhotoURL,
                myName: matchManager.myName,
                otherProfile: celebration.profile,
                otherPhotoURL: celebration.photoURL,
                matchId: celebration.match.id
            )
        }
        .environmentObject(notificationManager)
        .environmentObject(tabRouter)
        .environmentObject(matchManager)
        // 通知をタップした時、AppDelegate(UNUserNotificationCenterDelegate)が
        // NotificationRouter.shared.pendingTabに行き先タブをセットする。
        // AppDelegateからはTabRouterの実体(このViewの@StateObject)に直接触れないため、
        // ここで監視して受け渡す。
        .onReceive(NotificationRouter.shared.$pendingTab) { tab in
            guard let tab else { return }
            tabRouter.selectTab(tab)
            NotificationRouter.shared.pendingTab = nil
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                tabButton(.discover, icon: "magnifyingglass", label: "探す")
                tabButton(.gatherings, icon: "person.3.fill", label: "集まり", badge: notificationManager.gatheringsActionCount)
                tabButton(.chat, icon: "message.fill", label: "トーク", badge: notificationManager.unreadCount)
                tabButton(.myPage, icon: "person.fill", label: "マイページ", showDot: notificationManager.hasMyPageTodo, highlightWhenDot: true)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
    }

    /// highlightWhenDot: showDotが立っている間、アイコンをテーマカラーの丸バッジに乗せて目立たせる
    /// (足あとの新着や、プロフィールのやることリストが残っている時のマイページタブなど)。
    private func tabButton(_ tab: AppTab, icon: String, label: String, badge: Int = 0, showDot: Bool = false, highlightWhenDot: Bool = false) -> some View {
        let isHighlighted = showDot && highlightWhenDot
        return Button {
            tabRouter.selectTab(tab)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if isHighlighted {
                        Image(systemName: icon)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.brandPurple, in: Circle())
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 21))
                    }
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10).bold())
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.brandPurple, in: Circle())
                            .offset(x: 12, y: -8)
                    } else if showDot {
                        Circle()
                            .fill(Color.brandPurple)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                            .offset(x: isHighlighted ? 2 : 9, y: isHighlighted ? -2 : -6)
                    }
                }
                .frame(height: 30)
                Text(LocalizedStringKey(label))
                    .font(.caption2)
            }
            .foregroundStyle(tabRouter.selectedTab == tab || isHighlighted ? Color.brandPurple : Color(.systemGray))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}

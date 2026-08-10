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
                case .likes:
                    LikesView()
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
                otherProfile: celebration.profile,
                otherPhotoURL: celebration.photoURL,
                matchId: celebration.match.id
            )
        }
        .environmentObject(notificationManager)
        .environmentObject(tabRouter)
        .environmentObject(matchManager)
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                tabButton(.discover, icon: "magnifyingglass", label: "探す")
                tabButton(.likes, icon: "heart.fill", label: "グッド")
                tabButton(.chat, icon: "message.fill", label: "トーク", badge: notificationManager.unreadCount)
                tabButton(.myPage, icon: "person.fill", label: "マイページ", showDot: notificationManager.footprintsCount > 0)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
    }

    private func tabButton(_ tab: AppTab, icon: String, label: String, badge: Int = 0, showDot: Bool = false) -> some View {
        Button {
            tabRouter.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 21))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10).bold())
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.brandRed, in: Circle())
                            .offset(x: 12, y: -8)
                    } else if showDot {
                        Circle()
                            .fill(Color.brandRed)
                            .frame(width: 9, height: 9)
                            .offset(x: 9, y: -6)
                    }
                }
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(tabRouter.selectedTab == tab ? Color.brandRed : Color(.systemGray))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}

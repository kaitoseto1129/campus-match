//
//  RootGateView.swift
//  Matching App
//

import SwiftUI

/// ログイン後、プロフィールの必須項目(性別・生年月日・自己紹介・写真)が
/// 揃っているかを確認し、揃っていなければ先にプロフィール編集を完了してもらう。
struct RootGateView: View {
    @StateObject private var profileManager = ProfileManager()
    @State private var hasLoaded = false
    /// プロフィール完成後、初回だけプッシュ通知の許可案内を挟むためのフラグ。
    @AppStorage("hasRequestedNotificationPermission") private var hasRequestedNotificationPermission = false
    /// 起動時に一度だけ判定し、以後はProfileEditViewの「保存」成功コールバックでしか変えない。
    /// (写真を1枚追加するたびにphotos.countが変わって再評価されると、保存ボタンを押す前に
    /// 勝手に次の画面へ進んでしまうことがあったため、途中経過のreactiveな再評価に頼らないようにした)
    @State private var showingOnboarding = false

    var body: some View {
        Group {
            if !hasLoaded {
                SplashView()
            } else if showingOnboarding {
                ProfileEditView(profileManager: profileManager, isOnboarding: true) {
                    showingOnboarding = false
                }
            } else if !hasRequestedNotificationPermission {
                NotificationPermissionView {
                    hasRequestedNotificationPermission = true
                }
            } else {
                MainTabView()
            }
        }
        .task {
            await profileManager.load()
            let isComplete = (profileManager.profile?.isProfileComplete ?? false)
                && profileManager.photos.count >= ProfileEditView.minPhotoCount
            showingOnboarding = !isComplete
            hasLoaded = true
        }
    }
}

#Preview {
    RootGateView()
}

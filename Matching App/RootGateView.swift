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

    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
            } else if let profile = profileManager.profile,
                      profile.isProfileComplete,
                      profileManager.photos.count >= ProfileEditView.minPhotoCount {
                if !hasRequestedNotificationPermission {
                    NotificationPermissionView {
                        hasRequestedNotificationPermission = true
                    }
                } else {
                    MainTabView()
                }
            } else {
                ProfileEditView(profileManager: profileManager, isOnboarding: true)
            }
        }
        .task {
            await profileManager.load()
            hasLoaded = true
        }
    }
}

#Preview {
    RootGateView()
}

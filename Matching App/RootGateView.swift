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

    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
            } else if let profile = profileManager.profile,
                      profile.isProfileComplete,
                      profileManager.photos.count >= ProfileEditView.minPhotoCount {
                MainTabView()
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

//
//  RootGateView.swift
//  Matching App
//

import SwiftUI

/// ログイン後、プロフィールの必須項目(性別・生年月日・自己紹介・写真)が
/// 揃っているかを確認し、揃っていなければ先にプロフィール編集を完了してもらう。
struct RootGateView: View {
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var store = StoreManager()
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
            // 通信が一時的に失敗してprofileが取得できないと、既に登録済みのユーザーまで
            // 誤って「未登録」扱いにしてしまう(=もう一度プロフィール登録画面に飛ばされる)ため、
            // 取得できるまで数回リトライしてから判定する。
            for attempt in 0..<3 {
                await profileManager.load()
                if profileManager.profile != nil { break }
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            // 必須なのはメイン写真(orderNumber 0)のみ。サブ写真は任意なので枚数では判定しない。
            let isComplete = (profileManager.profile?.isProfileComplete ?? false)
                && profileManager.photos.contains { $0.orderNumber == 0 }
            showingOnboarding = !isComplete
            hasLoaded = true

            // サブスクの解約・失効は通常Appleからの通知(apple-notifications)で反映されるが、
            // 通知の遅延・失敗に備えて、起動時にも端末が持つ購入状態と突き合わせておく。
            await store.syncMembershipEntitlement()

            // 既に通知許可が下りている端末(再インストール後の再ログインなど)では、
            // 案内画面を経由しないためデバイストークンが再取得されない。起動のたびに確認しておく。
            if hasRequestedNotificationPermission {
                await PushTokenManager.reregisterIfAlreadyAuthorized()
            }
        }
    }
}

#Preview {
    RootGateView()
}

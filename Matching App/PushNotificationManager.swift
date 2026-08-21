//
//  PushNotificationManager.swift
//  Matching App
//

import UIKit
import UserNotifications
import Supabase

/// SwiftUIの `App` プロトコルにはAPNsのデバイストークン受け取りコールバックが無いため、
/// `@UIApplicationDelegateAdaptor` 経由でこのAppDelegateを差し込んで受け取る。
/// 許可リクエスト自体は `NotificationPermissionView` が行い、そこから
/// `UIApplication.shared.registerForRemoteNotifications()` が呼ばれた結果としてここに届く。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        // 起動直後、セッション復元(ログイン確定)より先にこのコールバックが届くことがあるため、
        // トークンは一旦端末に保存しておき、実際のアップロードはregisterPendingTokenIfNeeded()に任せる。
        UserDefaults.standard.set(token, forKey: "pendingPushToken")
        Task { await PushTokenManager.registerPendingTokenIfNeeded() }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("push notification registration failed: \(error)")
    }
}

private struct PushTokenPayload: Encodable {
    let userId: UUID
    let token: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
    }
}

enum PushTokenManager {
    /// 端末に保存済みのデバイストークンがあり、かつログイン済みであれば、Supabaseに登録する。
    /// - AppDelegateがトークンを受け取った直後(まだ未ログインの可能性がある)
    /// - ログイン/セッション復元が確定した直後(トークン受け取りの方が先だった場合に備える)
    /// の両方から呼ばれ、どちらが先に揃っても最終的に登録されるようにしている。
    static func registerPendingTokenIfNeeded() async {
        guard let token = UserDefaults.standard.string(forKey: "pendingPushToken"),
              let userId = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("push_tokens")
                .upsert(PushTokenPayload(userId: userId, token: token), onConflict: "user_id,token")
                .execute()
        } catch {
            print("push token upload error: \(error)")
        }
    }

    /// ログイン済みの端末で、既に通知許可が下りている場合(例: 再インストール後の再ログイン)、
    /// 案内画面(NotificationPermissionView)を経由せずデバイストークンの取得だけやり直す。
    static func reregisterIfAlreadyAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
    }
}

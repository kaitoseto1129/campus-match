//
//  PushNotificationManager.swift
//  Matching App
//

import UIKit
import Supabase

/// SwiftUIのApp protocolだけではAPNsのデバイストークン受信コールバックを受け取れないため、
/// UIApplicationDelegateAdaptor経由でこのAppDelegateを差し込んでいる。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PushTokenManager.upload(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("push registration error: \(error)")
    }
}

/// 端末のAPNsトークンをSupabaseに登録する。ログインしていない間に取得したトークンも
/// 使えるよう、ログイン完了後に改めて登録し直せるようにキャッシュしておく。
enum PushTokenManager {
    private static var pendingToken: String?

    static func upload(token: String) async {
        pendingToken = token
        guard let userId = supabase().auth.currentUser?.id else { return }
        await register(token: token, userId: userId)
    }

    /// ログイン直後、既に取得済みのトークンがあれば今のユーザーに紐付け直す。
    static func registerPendingTokenIfNeeded() async {
        guard let token = pendingToken, let userId = supabase().auth.currentUser?.id else { return }
        await register(token: token, userId: userId)
    }

    private struct PushTokenPayload: Encodable {
        let userId: UUID
        let token: String
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case token
        }
    }

    private static func register(token: String, userId: UUID) async {
        do {
            try await supabase()
                .from("push_tokens")
                .upsert(PushTokenPayload(userId: userId, token: token), onConflict: "user_id,token")
                .execute()
        } catch {
            print("push token upload error: \(error)")
        }
    }
}

/// いいね・マッチ・メッセージ受信時に、Supabase Edge Function「send-push」経由で
/// 対象ユーザーへプッシュ通知を送る。APNsの秘密鍵などはサーバー側にしか置かないため、
/// クライアントはこの薄いラッパーからEdge Functionを呼ぶだけで良い。
enum PushNotifier {
    private struct SendPushParams: Encodable {
        let userId: UUID
        let title: String
        let body: String
    }
    private struct SendPushResponse: Decodable {
        let success: Bool
    }

    /// 送信は失敗しても呼び出し元の処理(いいね送信・メッセージ送信など)を止めたくないため、
    /// エラーはログに残すだけで投げ直さない。
    static func notify(userId: UUID, title: String, body: String) async {
        do {
            let _: SendPushResponse = try await supabase().functions.invoke(
                "send-push",
                options: FunctionInvokeOptions(body: SendPushParams(userId: userId, title: title, body: body))
            )
        } catch {
            print("send push error: \(error)")
        }
    }
}

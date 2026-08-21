//
//  PushNotifier.swift
//  Matching App
//

import Foundation
import Supabase

/// いいね・マッチ・メッセージ受信など、他のユーザーに気付いてほしい出来事が起きた時に
/// Supabase Edge Function「send-push」を呼び出してプッシュ通知を送る。
/// 実際の送信(APNsへの署名付きリクエスト)はサーバー側で行うため、ここでは呼び出すだけでよい。
///
/// 送信先の端末が通知を許可していない・トークンが未登録などの場合は、Edge Function側が
/// 何もせず正常終了するだけなので、ここでは結果を厳密に確認せず失敗しても無視してよい
/// (通知が届かないだけで、いいね送信やメッセージ送信そのものの成否には影響させたくないため)。
enum PushNotifier {
    private struct NotifyParams: Encodable {
        let userId: UUID
        let title: String
        let body: String
    }

    private struct NotifyResponse: Decodable {
        let success: Bool
    }

    static func notify(userId: UUID, title: String, body: String) async {
        // 自分自身の操作(例: 自分でいいねした通知が自分に飛ぶ)を誤って送らないための保険。
        guard userId != supabase().auth.currentUser?.id else { return }
        do {
            let _: NotifyResponse = try await supabase().functions.invoke(
                "send-push",
                options: FunctionInvokeOptions(body: NotifyParams(userId: userId, title: title, body: body))
            )
        } catch {
            print("push notify error: \(error)")
        }
    }
}

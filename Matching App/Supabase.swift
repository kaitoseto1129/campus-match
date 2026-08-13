//
//  Supabase.swift
//  NaviMe
//
//  Created by Kaito Seto on 2026/07/20.
//

import Foundation
import Supabase

/// 呼び出しのたびに新しいSupabaseClientを作ると、クライアントごとに独立したセッション管理・
/// トークン自動リフレッシュが並行して走ってしまい、リフレッシュトークンの競合で
/// 「保存されているはずのセッションが無効になり、何度もログインを求められる」原因になる。
/// アプリ全体で1つのクライアントを共有することで、セッション状態を一箇所に集約する。
private let sharedSupabaseClient: SupabaseClient = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(formatter)

    return SupabaseClient(
        supabaseURL: URL(string: "https://mqmhzroizlszdeoqxydg.supabase.co")!,
          supabaseKey: "sb_publishable_W5_v1sAFCRWrckJ1zAwU4Q_OEuhFl4S",
        options: SupabaseClientOptions( db: SupabaseClientOptions.DatabaseOptions(encoder: encoder,decoder: decoder))
      )
}()

func supabase() -> SupabaseClient {
    sharedSupabaseClient
}





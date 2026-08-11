//
//  NGWordFilter.swift
//  Matching App
//

import Foundation

/// 自己紹介・一言コメント・チャットメッセージなど、ユーザーが自由入力するテキストに含まれる
/// 不適切な表現(性的な単語など)を弾くための簡易フィルタ。
/// 単語リスト自体はユーザーに見せる必要がないため、公開APIはBool判定のみを返す。
enum NGWordFilter {
    /// 実運用ではサーバー側(RLSやトリガー)でも二重にチェックするのが望ましいが、
    /// まずはクライアント側の入力時点でブロックする簡易版。
    private static let ngWords: [String] = [
        "セックス", "せっくす", "sex", "エッチ", "えっち", "AV女優", "風俗", "パパ活", "ママ活",
        "ワンナイト", "円光", "援交", "援助交際", "裏垢", "アダルト", "ヌード", "全裸", "性行為",
        "デリヘル", "ソープ", "ラブホ", "野球拳"
    ]

    static func containsNGWord(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return ngWords.contains { normalized.contains($0.lowercased()) }
    }
}

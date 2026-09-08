//
//  NGWordFilter.swift
//  Matching App
//

import Foundation

/// 自己紹介・一言コメント・集まりの募集文・グループトークなど、ユーザーが自由入力する
/// テキストに対する簡易フィルタ。単語リスト自体はユーザーに見せる必要がないため、
/// 公開APIは判定結果のみを返す。
enum NGWordFilter {
    /// 弾いた理由。呼び出し側でユーザーに出す文言を出し分けるために使う。
    enum Violation {
        /// 性的・わいせつな表現(利用規約 第4条)。
        case inappropriate
        /// 異性交際(恋愛・デート)目的をうかがわせる表現、および性別を指定した募集。
        /// 本アプリは異性交際の相手を紹介するサービスではないため、規約で禁止している。
        case datingIntent

        var message: String {
            switch self {
            case .inappropriate:
                return String.appLocalized("使用できない表現が含まれているため送信できません")
            case .datingIntent:
                return String.appLocalized("恋愛・デートの相手を求める内容や、性別を指定した募集は投稿できません")
            }
        }
    }

    /// 実運用ではサーバー側(RLSやトリガー)でも二重にチェックするのが望ましいが、
    /// まずはクライアント側の入力時点でブロックする簡易版。
    private static let ngWords: [String] = [
        "セックス", "せっくす", "sex", "エッチ", "えっち", "AV女優", "風俗", "パパ活", "ママ活",
        "ワンナイト", "円光", "援交", "援助交際", "裏垢", "アダルト", "ヌード", "全裸", "性行為",
        "デリヘル", "ソープ", "ラブホ", "野球拳"
    ]

    /// 異性交際目的をうかがわせる表現。誤検知を避けるため、単独では日常会話にも出る語
    /// (「デート」「彼氏」単体など)は入れず、募集・希望の意図が読み取れる形だけを対象にする。
    private static let datingIntentWords: [String] = [
        // 交際相手の募集
        "恋人募集", "恋人ぼしゅう", "彼氏募集", "彼女募集",
        "彼氏欲しい", "彼氏ほしい", "彼女欲しい", "彼女ほしい", "恋人欲しい", "恋人ほしい",
        "交際希望", "交際相手", "付き合いたい", "付き合える人", "デート相手", "デートしたい",
        // 出会い・恋活・婚活
        "出会い目的", "出会い求め", "出会いたい", "恋活", "婚活", "街コン", "合コン", "ごうコン",
        "マッチングアプリ",
        // 性別を指定した募集(性別を条件にした呼びかけは本アプリの前提を崩すため)
        "女子のみ", "男子のみ", "女性のみ", "男性のみ",
        "女子限定", "男子限定", "女性限定", "男性限定",
        "女子だけ", "男子だけ", "女の子だけ", "男の子だけ",
        "女子募集", "男子募集", "女性募集", "男性募集",
        "男女比", "男女半々"
    ]

    /// 引っかかった場合はその理由を返す。問題なければnil。
    static func violation(in text: String) -> Violation? {
        let normalized = text.lowercased()
        if ngWords.contains(where: { normalized.contains($0.lowercased()) }) { return .inappropriate }
        if datingIntentWords.contains(where: { normalized.contains($0.lowercased()) }) { return .datingIntent }
        return nil
    }

    /// 複数の入力欄をまとめて確認する。
    static func violation(inAny texts: [String]) -> Violation? {
        for text in texts {
            if let violation = violation(in: text) { return violation }
        }
        return nil
    }

    static func containsNGWord(_ text: String) -> Bool {
        violation(in: text) != nil
    }
}

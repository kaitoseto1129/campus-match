//
//  MatchScore.swift
//  Matching App
//

import Foundation

/// お相手との相性を0〜100%で算出する(VIPオプション限定で表示する機能)。
///
/// 趣味カードの重なりを主軸に、基本情報(居住地・大学・話せる言語・ライフスタイル・年齢差)を
/// 補助的な観点として重み付けして合成する。同じ2人なら常に同じ値になり、
/// 「見るたびに数字が変わる」ことがないようにしている。
struct MatchScore {
    let percent: Int
    /// 相性が高い理由として画面に出す短い文言(最大3つ)。
    let reasons: [String]
    /// 双方が選んでいる共通の趣味カード。
    let sharedHobbyCards: [HobbyCard]

    /// 各観点の重み。合計を1.0にしておく。
    private enum Weight {
        static let hobby = 0.45
        static let language = 0.15
        static let area = 0.12
        static let university = 0.10
        static let lifestyle = 0.10
        static let age = 0.08
    }

    static func compute(me: Profile, other: Profile) -> MatchScore {
        var score = 0.0
        var reasons: [String] = []

        // 1) 趣味カードの重なり具合(Jaccard係数)。共通が多いほど高い。
        let myHobbies = Set(me.hobbyCards)
        let otherHobbies = Set(other.hobbyCards)
        let sharedIds = myHobbies.intersection(otherHobbies)
        let unionCount = myHobbies.union(otherHobbies).count
        if unionCount > 0 {
            let jaccard = Double(sharedIds.count) / Double(unionCount)
            // 1つでも共通があれば十分に加点されるよう、平方根で立ち上がりを緩やかにする。
            score += Weight.hobby * jaccard.squareRoot()
        }
        let sharedCards = HobbyCard.cards(for: Array(sharedIds))
        if let first = sharedCards.first {
            reasons.append(sharedCards.count >= 2
                           ? "「\(first.title)」など\(sharedCards.count)個の趣味が共通"
                           : "「\(first.title)」が共通")
        }

        // 2) 話せる言語の重なり。
        let sharedLanguages = Set(me.languages).intersection(Set(other.languages))
        if !sharedLanguages.isEmpty {
            score += Weight.language
            if let language = sharedLanguages.sorted().first {
                reasons.append("\(language)で話せる")
            }
        }

        // 3) 居住地。
        if !me.area.isEmpty && me.area == other.area {
            score += Weight.area
            reasons.append("同じ\(other.area)在住")
        }

        // 4) 大学。
        if me.universityId == other.universityId {
            score += Weight.university
            reasons.append("同じ大学")
        }

        // 5) ライフスタイル(お酒・タバコ・体型の一致数)。
        var lifestyleMatches = 0
        if let a = me.drinking, let b = other.drinking, a == b, a != unselectedOption { lifestyleMatches += 1 }
        if let a = me.smoking, let b = other.smoking, a == b, a != unselectedOption { lifestyleMatches += 1 }
        if let a = me.bodyType, let b = other.bodyType, a == b, a != unselectedOption { lifestyleMatches += 1 }
        if lifestyleMatches > 0 {
            score += Weight.lifestyle * (Double(lifestyleMatches) / 3.0)
            reasons.append("ライフスタイルが近い")
        }

        // 6) 年齢差。近いほど高く、6歳差以上で0になる。
        if let myAge = me.age, let otherAge = other.age {
            let diff = Double(abs(myAge - otherAge))
            let closeness = max(0, 1 - diff / 6.0)
            score += Weight.age * closeness
            if diff <= 1 {
                reasons.append("年齢が近い")
            }
        }

        // どれも一致しない相手でも0%にはせず、下限を35%として体感的に自然な範囲に収める。
        let percent = Int((35 + score * 65).rounded())
        return MatchScore(
            percent: min(100, max(0, percent)),
            reasons: Array(reasons.prefix(3)),
            sharedHobbyCards: sharedCards
        )
    }

    var label: String {
        switch percent {
        case 90...: return "とても相性が良さそう!"
        case 75..<90: return "相性が良さそう"
        case 60..<75: return "話が合いそう"
        default: return "これから知っていこう"
        }
    }
}

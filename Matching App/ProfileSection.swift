//
//  ProfileSection.swift
//  Matching App
//

import Foundation

/// プロフィール画面内のセクション。上から順番に並んでおり、
/// 閲覧者がどこまでスクロールしたか(=どこで離脱したか)を計測するために使う。
enum ProfileSection: String, CaseIterable, Codable {
    case header
    case tagline
    case subPhotos
    case nameAgeArea
    case about
    case basicInfo
    case hobbyCards
    case otherProfiles

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var label: String {
        switch self {
        case .header: return "メイン写真"
        case .tagline: return "一言コメント"
        case .subPhotos: return "サブ写真"
        case .nameAgeArea: return "年齢・居住地"
        case .about: return "自己紹介文"
        case .basicInfo: return "基本情報"
        case .hobbyCards: return "趣味カード"
        case .otherProfiles: return "他のユーザーも見てみる(最後まで到達)"
        }
    }
}

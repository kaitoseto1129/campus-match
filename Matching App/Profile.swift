//
//  Profile.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/31.
//

import Foundation
struct Profile: Codable, Identifiable {
    let id: UUID
    let universityId: UUID
    let name: String
    /// サインアップ直後はまだ入力されていないため、DB上はNULL許容。
    let description: String?
    let gender: Gender?
    let birthday: Date?
    var age: Int? {
        guard let birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
    }
    var ageLabel: String {
        guard let age else { return "-" }
        return "\(age)歳"
    }
    /// gender・birthday・description・写真などプロフィールの必須項目が揃っているか。
    /// これが揃うまではオンボーディング(プロフィール編集の強制)を表示する。
    var isProfileComplete: Bool {
        gender != nil && birthday != nil && !(description ?? "").isEmpty
    }

    let profileImageUrlString: String?
    var profileImageUrl: URL? {
        guard let profileImageUrlString else { return nil }
        return URL(string: profileImageUrlString)
    }
    let area: String
    let height: Int?
    var heightLabel: String {
        guard let height else { return "-" }
        return "\(height)cm"
    }
    let major: String?
    /// 旧・単一選択の国籍。表示のフォールバック用に残しているが、編集・絞り込みはnationalitiesを使う。
    let nationality: String?
    /// 複数国籍を持つユーザーにも対応した、国籍の複数選択。
    let nationalities: [String]
    let tagline: String?
    let showLikeCount: Bool
    let remainingLikes: Int
    let privateMode: Bool
    let showOnlineStatus: Bool
    let shareBonusClaimed: Bool
    let isAdmin: Bool
    let drinking: String?
    let smoking: String?
    let bodyType: String?
    let languages: [String]
    let boostExpiresAtString: String?
    var boostExpiresAt: Date? {
        guard let boostExpiresAtString else { return nil }
        return ISO8601DateFormatter.matchingApp.date(from: boostExpiresAtString)
    }
    var isBoosted: Bool {
        guard let boostExpiresAt else { return false }
        return boostExpiresAt > Date()
    }
    let createdAtString: String?
    var joinBadgeLabel: String? {
        guard let createdAtString,
              let createdAt = ISO8601DateFormatter.matchingApp.date(from: createdAtString) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? Int.max
        if days <= 7 { return "今週入会" }
        if days <= 30 { return "今月入会" }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, gender, birthday, area, height, major, nationality, nationalities, tagline
        case profileImageUrlString = "profile_image_url"
        case universityId = "university_id"
        case showLikeCount = "show_like_count"
        case remainingLikes = "remaining_likes"
        case privateMode = "private_mode"
        case showOnlineStatus = "show_online_status"
        case shareBonusClaimed = "share_bonus_claimed"
        case isAdmin = "is_admin"
        case drinking, smoking
        case bodyType = "body_type"
        case languages
        case boostExpiresAtString = "boost_expires_at"
        case createdAtString = "created_at"
    }
}

struct ProfileCompleteness {
    let percent: Int
    let missingLabels: [String]
}

extension Profile {
    /// 任意項目の入力状況を含めたプロフィールの充実度。マイページのプログレスバー表示に使う。
    func completeness(photoCount: Int) -> ProfileCompleteness {
        var total = 0
        var done = 0
        var missing: [String] = []
        func check(_ label: String, _ isDone: Bool) {
            total += 1
            if isDone { done += 1 } else { missing.append(label) }
        }
        check("自己紹介", !(description ?? "").isEmpty)
        check("写真\(ProfileEditView.minPhotoCount)枚以上", photoCount >= ProfileEditView.minPhotoCount)
        check("一言コメント", !(tagline ?? "").isEmpty)
        check("専攻", !(major ?? "").isEmpty)
        check("自己紹介200文字以上", (description ?? "").count >= 200)
        let percent = total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())
        return ProfileCompleteness(percent: percent, missingLabels: missing)
    }

    /// 相手との共通点の数を簡易的に算出する(居住地・国籍・お酒・タバコ・体型・話せる言語)。
    /// いいね履歴画面の「共通点N」バッジ表示に使う。
    func commonPointsCount(with other: Profile) -> Int {
        var count = 0
        if area == other.area { count += 1 }
        if !Set(nationalities).isDisjoint(with: Set(other.nationalities)) { count += 1 }
        if let drinking, drinking == other.drinking { count += 1 }
        if let smoking, smoking == other.smoking { count += 1 }
        if let bodyType, bodyType == other.bodyType { count += 1 }
        if !Set(languages).isDisjoint(with: Set(other.languages)) { count += 1 }
        return count
    }
}

extension ISO8601DateFormatter {
    static let matchingApp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
struct ProfilePhoto: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let urlString: String
    var url: URL? {
        return URL(string: urlString)
    }
    var orderNumber: Int
    var isMain: Bool {
        return orderNumber == 0
    }
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case urlString = "url"
        case orderNumber = "order_number"
    }
}
struct University: Codable, Identifiable {
    let id: UUID
    let name: String
    let domain: String
    let country: String
    /// 都道府県(日本)または州(アメリカ)。データが無い大学ではnil。
    let prefecture: String?
}
enum Gender: String, Codable {
    case male, female
    var label: String {
        switch self {
        case .male: return "男性"
        case .female: return "女性"
        }
    }
}

let prefectures: [String] = [
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
    "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
    "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
    "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
    "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
    "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
    "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
]

let japanRegions: [(name: String, prefectures: [String])] = [
    ("北海道", ["北海道"]),
    ("東北", ["青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県"]),
    ("関東", ["茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県"]),
    ("中部", ["新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県"]),
    ("近畿", ["三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県"]),
    ("中国", ["鳥取県", "島根県", "岡山県", "広島県", "山口県"]),
    ("四国", ["徳島県", "香川県", "愛媛県", "高知県"]),
    ("九州・沖縄", ["福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"])
]

let nationalities: [String] = [
    "日本", "アメリカ", "韓国", "中国", "台湾", "その他"
]

/// 居住地の絞り込みで選べる国。日本・アメリカは都道府県/州まで選べ、それ以外は国単位の絞り込みとなる。
let residenceCountries: [String] = [
    "日本", "アメリカ", "韓国", "中国", "台湾", "香港", "イギリス", "フランス", "ドイツ",
    "カナダ", "オーストラリア", "シンガポール", "タイ", "ベトナム", "インドネシア", "その他"
]

let usStates: [String] = [
    "アラバマ州", "アラスカ州", "アリゾナ州", "アーカンソー州", "カリフォルニア州",
    "コロラド州", "コネチカット州", "デラウェア州", "フロリダ州", "ジョージア州",
    "ハワイ州", "アイダホ州", "イリノイ州", "インディアナ州", "アイオワ州",
    "カンザス州", "ケンタッキー州", "ルイジアナ州", "メイン州", "メリーランド州",
    "マサチューセッツ州", "ミシガン州", "ミネソタ州", "ミシシッピ州", "ミズーリ州",
    "モンタナ州", "ネブラスカ州", "ネバダ州", "ニューハンプシャー州", "ニュージャージー州",
    "ニューメキシコ州", "ニューヨーク州", "ノースカロライナ州", "ノースダコタ州", "オハイオ州",
    "オクラホマ州", "オレゴン州", "ペンシルベニア州", "ロードアイランド州", "サウスカロライナ州",
    "サウスダコタ州", "テネシー州", "テキサス州", "ユタ州", "バーモント州",
    "バージニア州", "ワシントン州", "ウェストバージニア州", "ウィスコンシン州", "ワイオミング州"
]

/// ライフスタイル系ピッカーの「未選択」を表す共通のプレースホルダー値。
/// 以前は各配列の先頭(実質のデフォルト値)が初期選択されてしまっていたため、
/// 明示的な未選択状態を持たせて「自分で選ぶまでは空欄」にできるようにしている。
let unselectedOption = "-"

let drinkingOptions: [String] = [unselectedOption, "飲む", "時々飲む", "飲まない"]
let smokingOptions: [String] = [unselectedOption, "吸わない", "禁煙中", "たまに吸う", "吸う"]
let bodyTypeOptions: [String] = [unselectedOption, "スリム", "やや細め", "普通", "グラマー", "筋肉質", "ややぽっちゃり", "太め"]
/// 話せる言語。検索して選べるよう、以前より幅広い選択肢を用意している。
let languageOptions: [String] = [
    "日本語", "英語", "中国語", "韓国語", "フランス語", "スペイン語", "ドイツ語",
    "イタリア語", "ポルトガル語", "ロシア語", "タイ語", "ベトナム語", "インドネシア語",
    "ヒンディー語", "アラビア語", "その他"
]

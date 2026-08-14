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
    /// 都道府県よりも詳細な市区町村(政令指定都市の区・東京23区など、データがある地域のみ)。任意項目。
    let city: String?
    /// 表示用に「都道府県 市区町村」を組み立てる。市区町村が無ければ都道府県のみ。
    var areaLabel: String {
        guard let city, !city.isEmpty else { return area }
        return "\(area) \(city)"
    }
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
    /// 会員ステータス(無料 / 有料 / VIP)。古いレコードや読み込み失敗時は無料会員として扱う。
    let membershipTier: MembershipTier?
    var membership: MembershipTier { membershipTier ?? .free }
    /// 選択した趣味カードのID一覧。
    let hobbyCards: [String]
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
        case id, name, description, gender, birthday, area, city, height, major, nationality, nationalities, tagline
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
        case membershipTier = "membership_tier"
        case hobbyCards = "hobby_cards"
        case boostExpiresAtString = "boost_expires_at"
        case createdAtString = "created_at"
    }
}

/// 会員ステータス。上位プランは下位プランの特典をすべて含む。
enum MembershipTier: String, Codable, CaseIterable {
    case free
    case premium
    case vip

    var label: String {
        switch self {
        case .free: return "無料会員"
        // premium/vipはUI上は「有料会員」1プランに統合しているため、同じラベルを返す。
        case .premium, .vip: return "有料会員"
        }
    }

    /// 月額料金(円)。無料会員は0円。
    var monthlyPriceYen: Int {
        switch self {
        case .free: return 0
        case .premium, .vip: return 2000
        }
    }

    /// free < premium < vip の順序。特典判定はこのランクの比較で行う。
    var rank: Int {
        switch self {
        case .free: return 0
        case .premium: return 1
        case .vip: return 2
        }
    }

    /// 1日に新しくメッセージを送れる相手の人数(無料会員のみ制限、有料会員は無制限)。
    /// 無料会員でもメッセージ自体は送れるが、1日に会話できる人数に上限を設けている。
    static let freeDailyMessagePartnerLimit = 3
    /// 1日にメッセージできる相手の人数に制限があるか。
    var hasDailyMessagePartnerLimit: Bool { rank < MembershipTier.premium.rank }
    /// 相手プロフィールで受け取ったいいね数を見られるか。
    var canSeeLikeCount: Bool { rank >= MembershipTier.premium.rank }
    /// 身バレ防止のプライベートモードを使えるか。
    var canUsePrivateMode: Bool { rank >= MembershipTier.vip.rank }
    /// トークで相手の既読が分かるか。
    var canSeeReadReceipts: Bool { rank >= MembershipTier.vip.rank }
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
        // メイン写真は必須で常に1枚あるため、充実度チェックでは任意のサブ写真も含めた枚数を目安にする。
        let recommendedPhotoCount = 1 + ProfileEditView.minSubPhotoCount
        check("写真\(recommendedPhotoCount)枚以上", photoCount >= recommendedPhotoCount)
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

/// 都道府県 → その下の市区町村(政令指定都市の区・東京23区など)の一覧。
/// ここにデータがある都道府県だけ、居住地選択・絞り込みで市区町村レベルまで選べるようになる。
/// データがない都道府県は、これまでどおり都道府県単位までの選択となる。
let japanMunicipalities: [String: [String]] = [
    "東京都": [
        "千代田区", "中央区", "港区", "新宿区", "文京区", "台東区", "墨田区", "江東区",
        "品川区", "目黒区", "大田区", "世田谷区", "渋谷区", "中野区", "杉並区", "豊島区",
        "北区", "荒川区", "板橋区", "練馬区", "足立区", "葛飾区", "江戸川区", "23区外"
    ],
    "北海道": [
        "札幌市中央区", "札幌市北区", "札幌市東区", "札幌市白石区", "札幌市豊平区",
        "札幌市南区", "札幌市西区", "札幌市厚別区", "札幌市手稲区", "札幌市清田区", "札幌市外"
    ],
    "宮城県": [
        "仙台市青葉区", "仙台市宮城野区", "仙台市若林区", "仙台市太白区", "仙台市泉区", "仙台市外"
    ],
    "埼玉県": [
        "さいたま市西区", "さいたま市北区", "さいたま市大宮区", "さいたま市見沼区", "さいたま市中央区",
        "さいたま市桜区", "さいたま市浦和区", "さいたま市南区", "さいたま市緑区", "さいたま市岩槻区", "さいたま市外"
    ],
    "千葉県": [
        "千葉市中央区", "千葉市花見川区", "千葉市稲毛区", "千葉市若葉区", "千葉市緑区", "千葉市美浜区", "千葉市外"
    ],
    "神奈川県": [
        "横浜市鶴見区", "横浜市神奈川区", "横浜市西区", "横浜市中区", "横浜市南区", "横浜市保土ケ谷区",
        "横浜市磯子区", "横浜市金沢区", "横浜市港北区", "横浜市戸塚区", "横浜市港南区", "横浜市旭区",
        "横浜市緑区", "横浜市瀬谷区", "横浜市栄区", "横浜市泉区", "横浜市青葉区", "横浜市都筑区",
        "川崎市川崎区", "川崎市幸区", "川崎市中原区", "川崎市高津区", "川崎市多摩区", "川崎市宮前区", "川崎市麻生区",
        "相模原市緑区", "相模原市中央区", "相模原市南区",
        "横浜・川崎・相模原以外"
    ],
    "新潟県": [
        "新潟市北区", "新潟市東区", "新潟市中央区", "新潟市江南区", "新潟市秋葉区",
        "新潟市南区", "新潟市西区", "新潟市西蒲区", "新潟市外"
    ],
    "静岡県": [
        "静岡市葵区", "静岡市駿河区", "静岡市清水区", "浜松市中央区", "浜松市浜名区", "浜松市天竜区", "静岡・浜松以外"
    ],
    "愛知県": [
        "名古屋市千種区", "名古屋市東区", "名古屋市北区", "名古屋市西区", "名古屋市中村区", "名古屋市中区",
        "名古屋市昭和区", "名古屋市瑞穂区", "名古屋市熱田区", "名古屋市中川区", "名古屋市港区", "名古屋市南区",
        "名古屋市守山区", "名古屋市緑区", "名古屋市名東区", "名古屋市天白区", "名古屋市外"
    ],
    "京都府": [
        "京都市北区", "京都市上京区", "京都市左京区", "京都市中京区", "京都市東山区", "京都市山科区",
        "京都市下京区", "京都市南区", "京都市右京区", "京都市伏見区", "京都市西京区", "京都市外"
    ],
    "大阪府": [
        "大阪市都島区", "大阪市福島区", "大阪市此花区", "大阪市西区", "大阪市港区", "大阪市大正区",
        "大阪市天王寺区", "大阪市浪速区", "大阪市西淀川区", "大阪市東淀川区", "大阪市東成区", "大阪市生野区",
        "大阪市旭区", "大阪市城東区", "大阪市阿倍野区", "大阪市住吉区", "大阪市東住吉区", "大阪市西成区",
        "大阪市淀川区", "大阪市鶴見区", "大阪市住之江区", "大阪市平野区", "大阪市北区", "大阪市中央区",
        "堺市堺区", "堺市中区", "堺市東区", "堺市西区", "堺市南区", "堺市北区", "堺市美原区",
        "大阪・堺以外"
    ],
    "兵庫県": [
        "神戸市東灘区", "神戸市灘区", "神戸市兵庫区", "神戸市長田区", "神戸市須磨区",
        "神戸市垂水区", "神戸市北区", "神戸市中央区", "神戸市西区", "神戸市外"
    ],
    "岡山県": [
        "岡山市北区", "岡山市中区", "岡山市東区", "岡山市南区", "岡山市外"
    ],
    "広島県": [
        "広島市中区", "広島市東区", "広島市南区", "広島市西区", "広島市安佐南区",
        "広島市安佐北区", "広島市安芸区", "広島市佐伯区", "広島市外"
    ],
    "福岡県": [
        "福岡市東区", "福岡市博多区", "福岡市中央区", "福岡市南区", "福岡市西区", "福岡市城南区", "福岡市早良区",
        "北九州市門司区", "北九州市若松区", "北九州市戸畑区", "北九州市小倉北区", "北九州市小倉南区",
        "北九州市八幡東区", "北九州市八幡西区",
        "福岡・北九州以外"
    ],
    "熊本県": [
        "熊本市中央区", "熊本市東区", "熊本市西区", "熊本市南区", "熊本市北区", "熊本市外"
    ]
]

let nationalities: [String] = [
    "日本", "アメリカ", "韓国", "中国", "台湾", "その他"
]

/// 居住地の絞り込みで選べる国。日本・アメリカは都道府県/州まで選べ、それ以外は国単位の絞り込みとなる。
let residenceCountries: [String] = [
    "日本", "アメリカ", "韓国", "中国", "台湾", "香港", "イギリス", "フランス", "ドイツ",
    "カナダ", "オーストラリア", "シンガポール", "タイ", "ベトナム", "インドネシア", "その他"
]

// アメリカの大学・学生向けの項目なので、日本語話者向けアプリの中でも州名は英語表記のまま扱う
// (カタカナ表記にすると米国の大学のprefectureと突き合わせづらく、当の米国人利用者にも不自然なため)。
let usStates: [String] = [
    "Alabama", "Alaska", "Arizona", "Arkansas", "California",
    "Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
    "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa",
    "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
    "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri",
    "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
    "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio",
    "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
    "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
    "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming",
    "District of Columbia"
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

//
//  Filtering.swift
//  Matching App
//

import Foundation

enum DiscoverSortOrder: Equatable {
    /// ログイン順(最終アクティブ順)
    case lastActive
    /// おすすめ順(簡易ロジック: 受け取ったいいねが多い順)
    case recommended
}

struct DiscoverFilter: Equatable {
    static let ageRange = 18...24
    static let heightRange = 140...200

    var ageMin: Int = DiscoverFilter.ageRange.lowerBound
    var ageMax: Int = DiscoverFilter.ageRange.upperBound
    var areas: Set<String> = []
    /// 居住地の国。都道府県/州のどちらのリストを見せるかの切り替えに使うだけで、
    /// 検索クエリ自体はareas(実際の値)で絞り込む。
    var areaCountry: String = "日本"
    var heightMin: Int = DiscoverFilter.heightRange.lowerBound
    var heightMax: Int = DiscoverFilter.heightRange.upperBound
    var nationalities: Set<String> = []
    /// nilなら大学IDでの絞り込みなし。値があればその大学のみ絞り込む。
    var universityId: UUID? = nil
    /// デフォルトはtrue(インターカレッジ、全大学が対象)。falseにすると自分の大学のみに絞り込む。
    var showAllUniversities: Bool = true
    var sortOrder: DiscoverSortOrder = .lastActive

    var isAgeFiltered: Bool {
        ageMin > Self.ageRange.lowerBound || ageMax < Self.ageRange.upperBound
    }
    var isHeightFiltered: Bool {
        heightMin > Self.heightRange.lowerBound || heightMax < Self.heightRange.upperBound
    }
    var isActive: Bool {
        isAgeFiltered || isHeightFiltered || !areas.isEmpty || !nationalities.isEmpty || universityId != nil || !showAllUniversities
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 「ageMin歳以上」を満たす誕生日の上限(この日以前に生まれていればageMin歳以上)
    var maxBirthdayString: String {
        let calendar = Calendar(identifier: .iso8601)
        let date = calendar.date(byAdding: .year, value: -ageMin, to: Date()) ?? Date()
        return Self.dayFormatter.string(from: date)
    }

    /// 「ageMax歳以下」を満たす誕生日の下限(この日以降に生まれていればageMax歳以下)
    var minBirthdayString: String {
        let calendar = Calendar(identifier: .iso8601)
        let cutoff = calendar.date(byAdding: .year, value: -(ageMax + 1), to: Date()) ?? Date()
        let nextDay = calendar.date(byAdding: .day, value: 1, to: cutoff) ?? cutoff
        return Self.dayFormatter.string(from: nextDay)
    }
}

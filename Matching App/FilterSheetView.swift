//
//  FilterSheetView.swift
//  Matching App
//

import SwiftUI
import Supabase

struct FilterSheetView: View {
    @Binding var filter: DiscoverFilter
    /// 絞り込み条件を渡すと、その条件でヒットする人数を返す(withの「N人に絞り込み中」のライブ表示用)。
    /// 渡さない画面(いいね一覧など)ではnilのままでよく、その場合ライブ件数は表示しない。
    var countProvider: ((DiscoverFilter) async -> Int)? = nil
    /// 探す画面の初回チュートリアル中に開かれた場合、「この条件で検索」ボタンを押すよう案内を出す。
    var showsTutorialHint: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DiscoverFilter
    @State private var universities: [University] = []
    @State private var previewCount: Int?
    @State private var isCounting = false
    @State private var countTask: Task<Void, Never>?
    /// 居住地選択が奥の階層まで進んだ時、選び終わったらここへ自動で戻すためのpath。
    @State private var path = NavigationPath()
    @State private var tutorialPulse = false

    init(filter: Binding<DiscoverFilter>, showsTutorialHint: Bool = false, countProvider: ((DiscoverFilter) async -> Int)? = nil) {
        self._filter = filter
        self._draft = State(initialValue: filter.wrappedValue)
        self.showsTutorialHint = showsTutorialHint
        self.countProvider = countProvider
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("プロフィール項目で絞り込み")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            NavigationLink {
                                AreaFilterView(draft: $draft, universities: universities, popToRoot: { path = NavigationPath() })
                            } label: {
                                filterRow(title: "居住地", value: areaSummary)
                            }
                            Divider().padding(.leading, 16)

                            NavigationLink {
                                RangeFilterView(
                                    title: "年齢",
                                    unit: "歳",
                                    range: DiscoverFilter.ageRange,
                                    min: $draft.ageMin,
                                    max: $draft.ageMax
                                )
                            } label: {
                                filterRow(title: "年齢", value: "\(draft.ageMin)歳 〜 \(draft.ageMax)歳")
                            }
                            Divider().padding(.leading, 16)

                            NavigationLink {
                                RangeFilterView(
                                    title: "身長",
                                    unit: "cm",
                                    range: DiscoverFilter.heightRange,
                                    min: $draft.heightMin,
                                    max: $draft.heightMax
                                )
                            } label: {
                                filterRow(title: "身長", value: "\(draft.heightMin)cm 〜 \(draft.heightMax)cm")
                            }
                            Divider().padding(.leading, 16)

                            NavigationLink {
                                MultiSelectFilterView(title: "国籍", options: nationalities, selected: $draft.nationalities)
                            } label: {
                                filterRow(title: "国籍", value: nationalitySummary)
                            }
                            Divider().padding(.leading, 16)

                            NavigationLink {
                                MultiSelectFilterView(title: "体型", options: bodyTypeOptions.filter { $0 != unselectedOption }, selected: $draft.bodyTypes)
                            } label: {
                                filterRow(title: "体型", value: bodyTypeSummary)
                            }
                            Divider().padding(.leading, 16)

                            NavigationLink {
                                UniversityFilterView(draft: $draft, universities: universities, universityCountries: universityCountries)
                            } label: {
                                filterRow(title: "大学", value: universitySummary)
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .background(Color.appListBackground.ignoresSafeArea())
            .navigationTitle("検索条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
        .task {
            await loadUniversities()
        }
        .onChange(of: draft) { _, newValue in
            scheduleCountRefresh(for: newValue)
        }
        .task {
            scheduleCountRefresh(for: draft)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if showsTutorialHint {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down")
                    Text("この「この条件で検索」ボタンを押してみましょう")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.brandOrange, in: RoundedRectangle(cornerRadius: 12))
            }
            if countProvider != nil {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    if isCounting && previewCount == nil {
                        ProgressView()
                    } else {
                        Text("\(previewCount ?? 0)人に絞り込み中")
                            .font(.subheadline.bold())
                    }
                }
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button {
                    draft = DiscoverFilter()
                } label: {
                    Text("リセット")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                }

                Button {
                    var applied = draft
                    if applied.ageMin > applied.ageMax { applied.ageMax = applied.ageMin }
                    if applied.heightMin > applied.heightMax { applied.heightMax = applied.heightMin }
                    filter = applied
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("この条件で検索")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.brandPurple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .overlay {
                    if showsTutorialHint {
                        Capsule()
                            .stroke(Color.brandOrange, lineWidth: 3)
                            .scaleEffect(tutorialPulse ? 1.12 : 1.0)
                            .opacity(tutorialPulse ? 0 : 1)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding()
        .background(.bar)
        .onAppear {
            if showsTutorialHint {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    tutorialPulse = true
                }
            }
        }
    }

    private func filterRow(title: String, value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.brandPurple)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var areaSummary: String {
        if draft.areas.isEmpty { return "指定なし" }
        if let city = draft.cities.first { return city }
        if draft.areas.count == 1 { return draft.areas.first ?? "" }
        return "\(draft.areas.count)件選択中"
    }

    private var nationalitySummary: String {
        if draft.nationalities.isEmpty { return "指定なし" }
        if draft.nationalities.count == 1 { return draft.nationalities.first ?? "" }
        return "\(draft.nationalities.count)件選択中"
    }

    private var bodyTypeSummary: String {
        if draft.bodyTypes.isEmpty { return "指定なし" }
        if draft.bodyTypes.count == 1 { return draft.bodyTypes.first ?? "" }
        return "\(draft.bodyTypes.count)件選択中"
    }

    private var universityCountries: [String] {
        Array(Set(universities.map(\.country))).sorted()
    }

    private var universitySummary: String {
        if let selected = universities.first(where: { $0.id == draft.universityId }) {
            return selected.name
        }
        return draft.showAllUniversities ? "すべての大学" : "自分の大学のみ"
    }

    private func scheduleCountRefresh(for draftFilter: DiscoverFilter) {
        guard let countProvider else { return }
        countTask?.cancel()
        isCounting = true
        countTask = Task {
            let count = await countProvider(draftFilter)
            guard !Task.isCancelled else { return }
            previewCount = count
            isCounting = false
        }
    }

    private func loadUniversities() async {
        do {
            universities = try await supabase()
                .from("universities")
                .select("*")
                .order("name", ascending: true)
                .execute()
                .value
        } catch {
            print("university list load error: \(error)")
        }
    }
}

private func multiSelectRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack {
            Text(LocalizedStringKey(title))
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.brandPurple)
            }
        }
        .contentShape(Rectangle())
    }
}

/// 居住地は「地方→都道府県」のように段階的に絞り込めるが、最終的に選べるのは1件だけ(単一選択)。
private struct AreaFilterView: View {
    @Binding var draft: DiscoverFilter
    let universities: [University]
    /// 選択が完了したら検索条件トップまで一気に戻す(以前は選ぶたびに手動で何度も戻る必要があった)。
    var popToRoot: () -> Void
    @State private var areaSearchText = ""

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    CountrySelectView(selectedCountry: $draft.areaCountry, onChange: {
                        draft.areas = []
                        draft.cities = []
                        areaSearchText = ""
                    })
                } label: {
                    HStack {
                        Text("国")
                        Spacer()
                        Text(draft.areaCountry)
                            .foregroundStyle(Color.brandPurple)
                    }
                }
            }

            if draft.areaCountry == "日本" {
                Section {
                    TextField("都道府県を検索", text: $areaSearchText)
                }
                if areaSearchText.isEmpty {
                    Section("地方から選ぶ") {
                        ForEach(japanRegions, id: \.name) { region in
                            NavigationLink {
                                PrefectureSingleSelectView(options: region.prefectures, title: region.name, searchPlaceholder: "都道府県を検索", draft: $draft, popToRoot: popToRoot)
                            } label: {
                                HStack {
                                    Text(region.name)
                                    Spacer()
                                    if let selected = draft.areas.first, region.prefectures.contains(selected) {
                                        Text(draft.cities.first ?? selected)
                                            .font(.caption)
                                            .foregroundStyle(Color.brandPurple)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(prefectures.filter { $0.contains(areaSearchText) }, id: \.self) { prefecture in
                            if let municipalities = japanMunicipalities[prefecture] {
                                NavigationLink {
                                    MunicipalitySingleSelectView(options: municipalities, prefecture: prefecture, draft: $draft, popToRoot: popToRoot)
                                } label: {
                                    HStack {
                                        Text(prefecture)
                                        Spacer()
                                        if draft.areas.contains(prefecture) {
                                            Text(draft.cities.first ?? "")
                                                .font(.caption)
                                                .foregroundStyle(Color.brandPurple)
                                        }
                                    }
                                }
                            } else {
                                multiSelectRow(title: prefecture, isSelected: draft.areas.contains(prefecture)) {
                                    selectSingle(prefecture, in: &draft.areas)
                                    draft.cities = []
                                    popToRoot()
                                }
                            }
                        }
                    }
                }
            } else if draft.areaCountry == "アメリカ" {
                Section {
                    TextField("州を検索", text: $areaSearchText)
                }
                Section {
                    let filteredStates = areaSearchText.isEmpty ? usStates : usStates.filter { $0.contains(areaSearchText) }
                    ForEach(filteredStates, id: \.self) { state in
                        multiSelectRow(title: state, isSelected: draft.areas.contains(state)) {
                            selectSingle(state, in: &draft.areas)
                            draft.cities = []
                            popToRoot()
                        }
                    }
                }
            } else {
                Section {
                    Button {
                        draft.areas = [draft.areaCountry]
                        draft.cities = []
                        popToRoot()
                    } label: {
                        HStack {
                            Text("\(draft.areaCountry)で絞り込む")
                            Spacer()
                            if draft.areas.first == draft.areaCountry {
                                Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                            }
                        }
                    }
                    Text("この国では都道府県/州単位の絞り込みは未対応のため、国単位で絞り込みます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("居住地")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectSingle(_ value: String, in set: inout Set<String>) {
        set = set.contains(value) ? [] : [value]
    }
}

/// 居住地の絞り込みで選べる国の検索画面。
private struct CountrySelectView: View {
    @Binding var selectedCountry: String
    var onChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? residenceCountries : residenceCountries.filter { $0.contains(searchText) }
    }

    var body: some View {
        Form {
            Section {
                TextField("国を検索", text: $searchText)
            }
            Section {
                ForEach(filtered, id: \.self) { country in
                    multiSelectRow(title: country, isSelected: selectedCountry == country) {
                        selectedCountry = country
                        onChange()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("国")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RangeFilterView: View {
    let title: String
    let unit: String
    let range: ClosedRange<Int>
    @Binding var min: Int
    @Binding var max: Int

    var body: some View {
        Form {
            Stepper("\(min)\(unit) 〜", value: $min, in: range)
            Stepper("〜 \(max)\(unit)", value: $max, in: range)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MultiSelectFilterView: View {
    let title: String
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        Form {
            ForEach(options, id: \.self) { option in
                multiSelectRow(title: option, isSelected: selected.contains(option)) {
                    if selected.contains(option) {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UniversityFilterView: View {
    @Binding var draft: DiscoverFilter
    let universities: [University]
    let universityCountries: [String]
    @State private var universitySearchText = ""

    /// 居住地で都道府県/州まで選ばれていれば、その地域にある大学だけに絞り込む。
    /// 該当大学が無ければ国単位に、国単位でも該当が無ければ全件にフォールバックする。
    private var prefectureFilteredUniversities: [University]? {
        guard let selectedArea = draft.areas.first, selectedArea != draft.areaCountry else { return nil }
        let matches = universities.filter { $0.prefecture == selectedArea }
        return matches.isEmpty ? nil : matches
    }
    private var isFilteredByArea: Bool {
        !draft.areas.isEmpty && universityCountries.contains(draft.areaCountry)
    }
    private var relevantUniversities: [University] {
        prefectureFilteredUniversities ?? (isFilteredByArea ? universities.filter { $0.country == draft.areaCountry } : universities)
    }
    private var relevantCountries: [String] {
        Array(Set(relevantUniversities.map(\.country))).sorted()
    }
    private var areaFilterCaption: String? {
        if let selectedArea = draft.areas.first, prefectureFilteredUniversities != nil {
            return "居住地の絞り込み(\(selectedArea))に合わせて大学を絞り込んでいます"
        }
        if isFilteredByArea {
            return "居住地の絞り込み(\(draft.areaCountry))に合わせて大学を絞り込んでいます"
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                multiSelectRow(title: "自分の大学のみ", isSelected: !draft.showAllUniversities && draft.universityId == nil) {
                    draft.showAllUniversities = false
                    draft.universityId = nil
                }
                multiSelectRow(title: "すべての大学", isSelected: draft.showAllUniversities) {
                    draft.showAllUniversities = true
                    draft.universityId = nil
                }
            }
            Section {
                TextField("大学名で検索", text: $universitySearchText)
            }
            if universitySearchText.isEmpty {
                if let caption = areaFilterCaption {
                    Section {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(relevantCountries, id: \.self) { country in
                        NavigationLink {
                            UniversityMultiSelectView(
                                universities: relevantUniversities.filter { $0.country == country },
                                title: country,
                                selectedId: $draft.universityId,
                                showAllUniversities: $draft.showAllUniversities
                            )
                        } label: {
                            HStack {
                                Text(country)
                                Spacer()
                                if let selected = universities.first(where: { $0.id == draft.universityId }), selected.country == country {
                                    Text(selected.name)
                                        .font(.caption)
                                        .foregroundStyle(Color.brandPurple)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            } else {
                Section {
                    ForEach(universities.filter { $0.name.contains(universitySearchText) }) { university in
                        multiSelectRow(title: "\(university.name)(\(university.country))", isSelected: draft.universityId == university.id) {
                            draft.universityId = university.id
                            draft.showAllUniversities = false
                        }
                    }
                }
            }
        }
        .navigationTitle("大学")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 居住地(都道府県/州)の単一選択画面。
private struct PrefectureSingleSelectView: View {
    let options: [String]
    let title: String
    var searchPlaceholder: String = "検索"
    @Binding var draft: DiscoverFilter
    var popToRoot: () -> Void
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? options : options.filter { $0.contains(searchText) }
    }

    var body: some View {
        Form {
            Section {
                TextField(searchPlaceholder, text: $searchText)
            }
            Section {
                ForEach(filtered, id: \.self) { option in
                    if let municipalities = japanMunicipalities[option] {
                        NavigationLink {
                            MunicipalitySingleSelectView(options: municipalities, prefecture: option, draft: $draft, popToRoot: popToRoot)
                        } label: {
                            HStack {
                                Text(option)
                                Spacer()
                                if draft.areas.contains(option) {
                                    Text(draft.cities.first ?? "")
                                        .font(.caption)
                                        .foregroundStyle(Color.brandPurple)
                                }
                            }
                        }
                    } else {
                        multiSelectRow(title: option, isSelected: draft.areas.contains(option)) {
                            draft.areas = draft.areas.contains(option) ? [] : [option]
                            draft.cities = []
                            popToRoot()
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 都道府県よりも詳細な市区町村(政令指定都市の区・東京23区など)の単一選択画面。
private struct MunicipalitySingleSelectView: View {
    let options: [String]
    let prefecture: String
    @Binding var draft: DiscoverFilter
    var popToRoot: () -> Void
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? options : options.filter { $0.contains(searchText) }
    }

    var body: some View {
        Form {
            Section {
                multiSelectRow(title: "\(prefecture)全体", isSelected: draft.areas.contains(prefecture) && draft.cities.isEmpty) {
                    draft.areas = [prefecture]
                    draft.cities = []
                    popToRoot()
                }
            }
            Section {
                TextField("市区町村を検索", text: $searchText)
            }
            Section {
                ForEach(filtered, id: \.self) { option in
                    multiSelectRow(title: option, isSelected: draft.cities.contains(option)) {
                        draft.areas = [prefecture]
                        draft.cities = [option]
                        popToRoot()
                    }
                }
            }
        }
        .navigationTitle(prefecture)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UniversityMultiSelectView: View {
    let universities: [University]
    let title: String
    @Binding var selectedId: UUID?
    @Binding var showAllUniversities: Bool
    @State private var searchText = ""

    private var filtered: [University] {
        searchText.isEmpty ? universities : universities.filter { $0.name.contains(searchText) }
    }

    var body: some View {
        Form {
            Section {
                TextField("大学名で検索", text: $searchText)
            }
            Section {
                ForEach(filtered) { university in
                    multiSelectRow(title: university.name, isSelected: selectedId == university.id) {
                        selectedId = university.id
                        showAllUniversities = false
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    FilterSheetView(filter: .constant(DiscoverFilter()))
}

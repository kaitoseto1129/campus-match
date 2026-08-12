//
//  SwiftUIView.swift
//  Matching App
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @ObservedObject var profileManager: ProfileManager
    /// 新規登録直後の必須項目入力(オンボーディング)として表示している場合はtrue。
    /// この場合はキャンセルできないようにする。
    var isOnboarding: Bool = false
    /// マイページの「やることリスト」から遷移した場合、開いた直後にその項目のセクションまで自動スクロールする。
    var initialFocusSectionId: String? = nil
    @Environment(\.dismiss) var dismiss
    @State var name: String = ""
    @State var description: String = ""
    @State var gender: Gender = .male
    @State var birthday: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State var area: String = ""
    @State var height: Int? = nil
    @State var major: String = ""
    @State var nationalities: Set<String> = []
    @State var tagline: String = ""
    @State var drinking: String = unselectedOption
    @State var smoking: String = unselectedOption
    @State var bodyType: String = unselectedOption
    @State var languages: Set<String> = []
    @State var replyPace: String = unselectedOption
    @State var pickerItem: PhotosPickerItem? = nil
    /// 直近でタップした写真スロット(0=メイン, 1〜3=サブ)。pickerItemが確定した時にどこへ入れるか判定するために使う。
    @State var pickerTargetSlot: Int = 0
    @State var showingSaveFailAlert : Bool = false
    @State var faceCheckMessage: String = ""
    @State var showingFaceCheckAlert: Bool = false
    @State var validationMessage: String = ""
    @State var showingValidationAlert: Bool = false
    @State var cropperImage: IdentifiableImage? = nil
    @State var cropperContinuation: CheckedContinuation<UIImage?, Never>? = nil
    @State var showingPreview: Bool = false
    @State var showingAIComposer: Bool = false
    @State var showingBirthdayPicker: Bool = false
    @State var showingLanguagePicker: Bool = false
    @State var showingNationalityPicker: Bool = false
    @State var showingAreaPicker: Bool = false
    @State var showingGenderPicker: Bool = false
    @State var showingHeightPicker: Bool = false

    /// 写真をトリミング画面に渡し、ユーザーが決定した範囲だけを切り出した画像を返す(キャンセル時はnil)。
    func presentCropper(for image: UIImage) async -> UIImage? {
        await withCheckedContinuation { continuation in
            cropperContinuation = continuation
            cropperImage = IdentifiableImage(image: image)
        }
    }

    /// completeness()が返すラベル文字列から、対応するセクションidへの割り当て。
    /// マイページの「やることリスト」の編集ボタンから、該当セクションまで自動スクロールさせるために使う。
    static func sectionId(for missingLabel: String) -> String {
        if missingLabel.contains("自己紹介") { return "about" }
        if missingLabel.contains("写真") { return "photos" }
        if missingLabel.contains("一言コメント") { return "tagline" }
        if missingLabel.contains("専攻") { return "basic" }
        return "basic"
    }

    static let minDescriptionLength = 50
    static let minPhotoCount = 4 // メイン1枚 + サブ3枚
    static let maxTaglineLength = 20

    var taglineSection: some View {
        Section("一言コメント(任意)") {
            TextField("例: 都内在住、大学生です!", text: $tagline)
                .onChange(of: tagline) { _, newValue in
                    if newValue.count > Self.maxTaglineLength {
                        tagline = String(newValue.prefix(Self.maxTaglineLength))
                    }
                }
            Text("\(tagline.count) / \(Self.maxTaglineLength)文字")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .id("tagline")
    }

    /// メイン写真とサブ写真をそれぞれ別セクションに分けて、迷わないようにしている。
    /// 指定したスロット(0=メイン, 1〜3=サブ)に登録済みの写真。order_numberで探すため、
    /// メインが空でもサブだけ先に登録されている状態を正しく表示できる。
    private func photo(forSlot slot: Int) -> ProfilePhoto? {
        profileManager.photos.first { $0.orderNumber == slot }
    }

    var photosSection: some View {
        Group {
            Section("メイン写真(必須)") {
                if let mainPhoto = photo(forSlot: 0) {
                    editablePhotoCell(mainPhoto)
                        .frame(width: 100, height: 100)
                } else {
                    emptyPhotoSlot(label: "メイン写真を追加", slot: 0)
                        .frame(width: 100, height: 100)
                }
                Text("あなたの顔がはっきり写っている写真を選んでください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("サブ写真(必須・3枚)") {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1..<Self.minPhotoCount, id: \.self) { slot in
                        if let subPhoto = photo(forSlot: slot) {
                            editablePhotoCell(subPhoto)
                        } else {
                            emptyPhotoSlot(label: "サブ\(slot)", slot: slot)
                        }
                    }
                }
                Text("メインより先に、この3枚から登録しても大丈夫です")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .id("photos")
    }
    func emptyPhotoSlot(label: String, slot: Int) -> some View {
        // どのスロットが空でも、そこだけを狙って個別に選べるようにする
        // (以前はメインが空の状態でサブを選ぶと、メイン用の顔判定が誤って走ってしまっていた)。
        PhotosPicker(selection: $pickerItem, matching: .images) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .frame(height: 80)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text(label)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                }
        }
        .simultaneousGesture(TapGesture().onEnded { pickerTargetSlot = slot })
    }
    func editablePhotoCell(_ photo: ProfilePhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: photo.url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if photo.isMain {
                Text("メイン")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in:Capsule())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .background(.black.opacity(0.2))
                    .padding(6)
            }
            Button {
                Task {
                    await profileManager.deletePhoto(photo: photo)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.3))
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 80)
        .contextMenu {
            if !photo.isMain {
                Button {
                    Task {
                        await profileManager.makeMain(photo:photo)
                    }
                } label: {
                    Label("メインにする",systemImage: "star")
                }
            }
        }
    }

    private func formRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .buttonStyle(.plain)
    }

    var basicSection: some View {
        Section {
            TextField("ニックネーム(必須)", text: $name)
            TextField("専攻(任意)", text: $major)
            formRow(title: "誕生日(必須)", value: birthdayLabel) { showingBirthdayPicker = true }
            formRow(title: "性別(必須)", value: gender.label) { showingGenderPicker = true }
            formRow(title: "居住地(必須)", value: area.isEmpty ? "-" : area) { showingAreaPicker = true }
            formRow(title: "身長(必須)", value: height.map { "\($0)cm" } ?? "選択してください") { showingHeightPicker = true }
            formRow(title: "国籍(任意・複数選択可)", value: nationalities.isEmpty ? "-" : nationalities.sorted().joined(separator: "・")) {
                showingNationalityPicker = true
            }
        }
        .id("basic")
    }

    private var birthdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: birthday)
    }

    var lifestyleSection: some View {
        Section("ライフスタイル(任意)") {
            Picker("お酒", selection: $drinking) {
                ForEach(drinkingOptions, id: \.self) { Text($0).tag($0) }
            }
            Picker("タバコ", selection: $smoking) {
                ForEach(smokingOptions, id: \.self) { Text($0).tag($0) }
            }
            Picker("体型", selection: $bodyType) {
                ForEach(bodyTypeOptions, id: \.self) { Text($0).tag($0) }
            }
            Picker("返信ペース", selection: $replyPace) {
                ForEach(replyPaceOptions, id: \.self) { Text($0).tag($0) }
            }
            formRow(title: "話せる言語", value: languages.isEmpty ? "-" : languages.sorted().joined(separator: "・")) {
                showingLanguagePicker = true
            }
        }
        .id("lifestyle")
    }
    var aboutSection: some View {
        Section("自己紹介(必須・50文字以上)") {
            TextField("自己紹介を書きましょう", text: $description,axis: .vertical)
                .lineLimit(6...14)
            HStack {
                Button("AIで作成する") {
                    showingAIComposer = true
                }
                .font(.caption)
                Spacer()
                Text("\(description.count) / \(Self.minDescriptionLength)文字以上")
                    .font(.caption)
                    .foregroundStyle(description.count >= Self.minDescriptionLength ? .secondary : Color.brandBlue)
            }
        }
        .id("about")
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    photosSection
                    taglineSection
                    basicSection
                    lifestyleSection
                    aboutSection
                }
                .onAppear {
                    if let target = initialFocusSectionId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { proxy.scrollTo(target, anchor: .top) }
                        }
                    }
                }
            }
            .navigationTitle(Text(isOnboarding ? "プロフィールを完成させましょう" : "プロフィール編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction){
                        Button("キャンセル"){dismiss()}
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("プレビュー") { showingPreview = true }
                        .font(.subheadline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
        .onAppear {
            if let profile = profileManager.profile {
                self.name = profile.name
                self.description = profile.description ?? ""
                self.gender = profile.gender ?? .male
                self.birthday = profile.birthday ?? (Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date())
                self.area = profile.area.isEmpty ? (prefectures.first ?? "") : profile.area
                self.height = profile.height
                self.major = profile.major ?? ""
                self.nationalities = Set(profile.nationalities)
                self.tagline = profile.tagline ?? ""
                self.drinking = profile.drinking ?? unselectedOption
                self.smoking = profile.smoking ?? unselectedOption
                self.bodyType = profile.bodyType ?? unselectedOption
                self.languages = Set(profile.languages)
                self.replyPace = profile.replyPace ?? unselectedOption
            } else if area.isEmpty {
                area = prefectures.first ?? ""
            }
        }
        .onChange(of: pickerItem) {oldValue, newValue in
            let targetSlot = pickerTargetSlot
            Task {
                guard let newValue, let data = try? await newValue.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    pickerItem = nil
                    return
                }
                pickerItem = nil
                // PhotosPickerのシートが閉じきる前に次のfullScreenCover(トリミング画面)を出そうとすると、
                // 提示が無視されて「もう一度タップしないと反映されない」ように見える不具合があったため、
                // シートの dismiss アニメーションが終わるのを少し待ってから提示する。
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let croppedImage = await presentCropper(for: image) else { return }

                // メイン写真(スロット0)だけ顔検出を行う。サブ写真は風景や物の写真でも良いので対象外にする。
                // タップしたスロットで判定するため、メインが空のままサブから登録しても誤って
                // 顔判定にかからない(=何度も選び直す羽目にならない)。
                if targetSlot == 0 {
                    let result = await FaceDetector().checkFace(image: croppedImage)
                    guard case .ok = result else {
                        faceCheckMessage = result.message ?? "顔が写っている写真を選んでください"
                        showingFaceCheckAlert = true
                        return
                    }
                }
                await profileManager.addPhoto(image: croppedImage, atSlot: targetSlot)
                // addPhoto失敗時はerrorMessageが立つだけで画面に何も表示されず、
                // 「追加したのに反映されない」ように見えてしまっていたため、ここで拾って表示する。
                if let error = profileManager.errorMessage {
                    faceCheckMessage = error
                    showingFaceCheckAlert = true
                    profileManager.errorMessage = nil
                }
            }
        }
        .fullScreenCover(item: $cropperImage) { wrapper in
            PhotoCropperView(image: wrapper.image) { result in
                cropperContinuation?.resume(returning: result)
                cropperContinuation = nil
                cropperImage = nil
            }
        }
        .sheet(isPresented: $showingBirthdayPicker) {
            BirthdayPickerView(birthday: $birthday)
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguageMultiSelectView(selected: $languages)
        }
        .sheet(isPresented: $showingNationalityPicker) {
            NationalityMultiSelectView(selected: $nationalities)
        }
        .sheet(isPresented: $showingAreaPicker) {
            ResidencePickerView(area: $area)
        }
        .confirmationDialog("性別", isPresented: $showingGenderPicker, titleVisibility: .visible) {
            Button(Gender.male.label) { gender = .male }
            Button(Gender.female.label) { gender = .female }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showingHeightPicker) {
            HeightPickerView(height: $height)
        }
        .sheet(isPresented: $showingAIComposer) {
            AIBioComposerView { generated in
                description = generated
                showingAIComposer = false
            }
        }
        .sheet(isPresented: $showingPreview) {
            NavigationStack {
                ProfileDisplayView(
                    profile: draftPreviewProfile,
                    university: profileManager.university,
                    photos: profileManager.photos
                ) {
                    Text("これはプレビューです")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .navigationTitle("プレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { showingPreview = false }
                    }
                }
            }
        }
        .alert("写真を追加できません", isPresented: $showingFaceCheckAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(faceCheckMessage)
        }
        .alert("保存に失敗しました", isPresented: $showingSaveFailAlert) {
            Button("ok", role: .cancel) {}
            Button("リトライ") {
                save()
            }
        }
        .alert("入力内容を確認してください", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    /// 保存前のプレビュー表示用に、現在編集中の値から一時的なProfileを組み立てる。
    private var draftPreviewProfile: Profile {
        let base = profileManager.profile
        return Profile(
            id: base?.id ?? UUID(),
            universityId: base?.universityId ?? UUID(),
            name: name,
            description: description,
            gender: gender,
            birthday: birthday,
            profileImageUrlString: base?.profileImageUrlString,
            area: area,
            height: height,
            major: major,
            nationality: nationalities.first,
            nationalities: Array(nationalities),
            tagline: tagline,
            showLikeCount: base?.showLikeCount ?? true,
            remainingLikes: base?.remainingLikes ?? 0,
            privateMode: base?.privateMode ?? false,
            showOnlineStatus: base?.showOnlineStatus ?? true,
            shareBonusClaimed: base?.shareBonusClaimed ?? false,
            isAdmin: base?.isAdmin ?? false,
            drinking: drinking,
            smoking: smoking,
            bodyType: bodyType,
            languages: Array(languages),
            replyPace: replyPace,
            boostExpiresAtString: base?.boostExpiresAtString,
            createdAtString: base?.createdAtString
        )
    }

    func save() {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "ニックネームを入力してください"
            showingValidationAlert = true
            return
        }
        if description.count < Self.minDescriptionLength {
            validationMessage = "自己紹介文は\(Self.minDescriptionLength)文字以上入力してください"
            showingValidationAlert = true
            return
        }
        if NGWordFilter.containsNGWord(description) || NGWordFilter.containsNGWord(tagline) {
            validationMessage = "自己紹介または一言コメントに使用できない表現が含まれています"
            showingValidationAlert = true
            return
        }
        if profileManager.photos.count < Self.minPhotoCount {
            validationMessage = "写真をメイン1枚+サブ3枚、合計\(Self.minPhotoCount)枚を追加してください"
            showingValidationAlert = true
            return
        }
        guard let height else {
            validationMessage = "身長を選択してください"
            showingValidationAlert = true
            return
        }
        Task {
            let suceeded = await profileManager.save(name: name, description: description, gender: gender, birthday: birthday, area: area, height: height, major: major, nationalities: Array(nationalities), tagline: tagline, drinking: drinking, smoking: smoking, bodyType: bodyType, languages: Array(languages), replyPace: replyPace)
            if suceeded {
                dismiss()
                await profileManager.load()
            } else {
                showingSaveFailAlert = true
            }
        }
    }
}

/// 誕生日をカレンダーグリッドではなく、年・月・日のホイールで手早く選べるようにした画面。
struct BirthdayPickerView: View {
    @Binding var birthday: Date
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date

    init(birthday: Binding<Date>) {
        self._birthday = birthday
        self._draft = State(initialValue: birthday.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            DatePicker("誕生日", selection: $draft, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
            .navigationTitle("誕生日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        birthday = draft
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
    }
}

/// 身長をホイールで選ぶ画面。
struct HeightPickerView: View {
    @Binding var height: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Int

    init(height: Binding<Int?>) {
        self._height = height
        self._draft = State(initialValue: height.wrappedValue ?? 165)
    }

    var body: some View {
        NavigationStack {
            Picker("身長", selection: $draft) {
                ForEach(140...200, id: \.self) { cm in
                    Text("\(cm)cm").tag(cm)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .navigationTitle("身長")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        height = draft
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
    }
}

/// 話せる言語の検索・複数選択画面。
struct LanguageMultiSelectView: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? languageOptions : languageOptions.filter { $0.contains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("言語を検索", text: $searchText)
                }
                Section {
                    ForEach(filtered, id: \.self) { language in
                        Button {
                            if selected.contains(language) {
                                selected.remove(language)
                            } else {
                                selected.insert(language)
                            }
                        } label: {
                            HStack {
                                Text(language).foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(language) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brandBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("話せる言語")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

/// 国籍の検索・複数選択画面。複数の国籍を持つユーザーにも対応する。
struct NationalityMultiSelectView: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? nationalities : nationalities.filter { $0.contains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("国籍を検索", text: $searchText)
                }
                Section {
                    ForEach(filtered, id: \.self) { nation in
                        Button {
                            if selected.contains(nation) {
                                selected.remove(nation)
                            } else {
                                selected.insert(nation)
                            }
                        } label: {
                            HStack {
                                Text(nation).foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(nation) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brandBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("国籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

/// プロフィールの居住地を「国→都道府県/州」の順で選べる画面(絞り込み画面と同じ考え方の単一選択版)。
struct ResidencePickerView: View {
    @Binding var area: String
    @Environment(\.dismiss) private var dismiss
    @State private var country: String
    @State private var searchText = ""

    init(area: Binding<String>) {
        self._area = area
        let initial = area.wrappedValue
        if usStates.contains(initial) {
            self._country = State(initialValue: "アメリカ")
        } else {
            self._country = State(initialValue: "日本")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        CountrySearchView(selectedCountry: $country) {
                            searchText = ""
                        }
                    } label: {
                        HStack {
                            Text("国")
                            Spacer()
                            Text(country).foregroundStyle(Color.brandBlue)
                        }
                    }
                }

                if country == "日本" {
                    Section {
                        TextField("都道府県を検索", text: $searchText)
                    }
                    if searchText.isEmpty {
                        Section("地方から選ぶ") {
                            ForEach(japanRegions, id: \.name) { region in
                                NavigationLink {
                                    PrefectureListView(options: region.prefectures, title: region.name, area: $area) { dismiss() }
                                } label: {
                                    HStack {
                                        Text(region.name)
                                        Spacer()
                                        if region.prefectures.contains(area) {
                                            Text(area).font(.caption).foregroundStyle(Color.brandBlue)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Section {
                            ForEach(prefectures.filter { $0.contains(searchText) }, id: \.self) { prefecture in
                                selectableRow(prefecture)
                            }
                        }
                    }
                } else if country == "アメリカ" {
                    Section {
                        TextField("州を検索", text: $searchText)
                    }
                    Section {
                        let filteredStates = searchText.isEmpty ? usStates : usStates.filter { $0.contains(searchText) }
                        ForEach(filteredStates, id: \.self) { state in
                            selectableRow(state)
                        }
                    }
                } else {
                    Section {
                        Button {
                            area = country
                            dismiss()
                        } label: {
                            HStack {
                                Text(country)
                                Spacer()
                                if area == country {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brandBlue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("居住地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func selectableRow(_ value: String) -> some View {
        Button {
            area = value
            dismiss()
        } label: {
            HStack {
                Text(value).foregroundStyle(.primary)
                Spacer()
                if area == value {
                    Image(systemName: "checkmark").foregroundStyle(Color.brandBlue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CountrySearchView: View {
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
                    Button {
                        selectedCountry = country
                        onChange()
                        dismiss()
                    } label: {
                        HStack {
                            Text(country).foregroundStyle(.primary)
                            Spacer()
                            if selectedCountry == country {
                                Image(systemName: "checkmark").foregroundStyle(Color.brandBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("国")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrefectureListView: View {
    let options: [String]
    let title: String
    @Binding var area: String
    var onSelect: () -> Void
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? options : options.filter { $0.contains(searchText) }
    }

    var body: some View {
        Form {
            Section {
                TextField("検索", text: $searchText)
            }
            Section {
                ForEach(filtered, id: \.self) { option in
                    Button {
                        area = option
                        onSelect()
                    } label: {
                        HStack {
                            Text(option).foregroundStyle(.primary)
                            Spacer()
                            if area == option {
                                Image(systemName: "checkmark").foregroundStyle(Color.brandBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileEditView(profileManager: ProfileManager())
}

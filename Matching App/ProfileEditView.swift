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
    @State var nationality: String? = nil
    @State var tagline: String = ""
    @State var drinking: String = unselectedOption
    @State var smoking: String = unselectedOption
    @State var bodyType: String = unselectedOption
    @State var languages: Set<String> = []
    @State var replyPace: String = unselectedOption
    @State var replyTime: String = unselectedOption
    @State var pickerItem: PhotosPickerItem? = nil
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
    static let descriptionTemplate = "【仕事】サラリーマンをしています\n\n【趣味】カフェ巡りと映画鑑賞です\n\n【好きな食べ物】ラーメンとお寿司が好きです\n"
    static let maxTaglineLength = 20

    var taglineSection: some View {
        Section("一言コメント") {
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

    /// メイン1枠+サブ3枠の固定レイアウト。空き枠は薄いプレースホルダーで「メイン」「サブ1」等のラベルを出す。
    var photosSection: some View {
        Section {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<Self.minPhotoCount, id: \.self) { slot in
                    if slot < profileManager.photos.count {
                        editablePhotoCell(profileManager.photos[slot])
                    } else {
                        emptyPhotoSlot(isMain: slot == 0, label: slot == 0 ? "メイン" : "サブ\(slot)")
                    }
                }
            }
            Text("メイン写真1枚+サブ写真3枚を登録してください")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .id("photos")
    }
    func emptyPhotoSlot(isMain: Bool, label: String) -> some View {
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
                    }
                    .foregroundStyle(.secondary)
                }
        }
    }
    func editablePhotoCell(_ photo: ProfilePhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: photo.url) { image in
                image.resizable().scaledToFill()
                    .frame(width: 80, height: 80)
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
    var basicSection: some View {
        VStack {
            TextField("ニックネーム", text: $name)
            TextField("専攻", text: $major)
            Button {
                showingBirthdayPicker = true
            } label: {
                HStack {
                    Text("誕生日")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(birthdayLabel)
                        .foregroundStyle(.secondary)
                }
            }
            Picker("性別", selection: $gender) {
                Text(Gender.male.label).tag(Gender.male)
                Text(Gender.female.label).tag(Gender.female)
            }
            Picker("居住地", selection: $area) {
                ForEach(prefectures, id:\.self) {prefecture in
                    Text(prefecture).tag(prefecture)}
            }
            Picker("身長", selection: $height) {
                Text("選択してください").tag(Int?.none)
                ForEach(140...200, id: \.self) { cm in
                    Text("\(cm)cm").tag(Int?.some(cm))
                }
            }
            Picker("国籍(任意)", selection: $nationality) {
                Text("選択してください").tag(String?.none)
                ForEach(nationalities, id: \.self) { nation in
                    Text(nation).tag(String?.some(nation))
                }
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
            Picker("よく返信する時間帯", selection: $replyTime) {
                ForEach(replyTimeOptions, id: \.self) { Text($0).tag($0) }
            }
            Button {
                showingLanguagePicker = true
            } label: {
                HStack {
                    Text("話せる言語")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(languages.isEmpty ? "-" : languages.sorted().joined(separator: "・"))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .id("lifestyle")
    }
    var aboutSection: some View {
        Section("自己紹介") {
            TextField("自己紹介を書きましょう", text: $description,axis: .vertical)
                .lineLimit(6...14)
            HStack {
                Button("テンプレートを使う") {
                    description = Self.descriptionTemplate
                }
                .font(.caption)
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
                self.nationality = (profile.nationality?.isEmpty ?? true) ? nil : profile.nationality
                self.tagline = profile.tagline ?? ""
                self.drinking = profile.drinking ?? unselectedOption
                self.smoking = profile.smoking ?? unselectedOption
                self.bodyType = profile.bodyType ?? unselectedOption
                self.languages = Set(profile.languages)
                self.replyPace = profile.replyPace ?? unselectedOption
                self.replyTime = profile.replyTime ?? unselectedOption
            } else if area.isEmpty {
                area = prefectures.first ?? ""
            }
        }
        .onChange(of: pickerItem) {oldValue, newValue in
            Task {
                guard let newValue, let data = try? await newValue.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    pickerItem = nil
                    return
                }
                pickerItem = nil
                guard let croppedImage = await presentCropper(for: image) else { return }
                let result = await FaceDetector().checkFace(image: croppedImage)

                if case .ok = result {
                    await profileManager.addPhoto(image: croppedImage)
                    // addPhoto失敗時はerrorMessageが立つだけで画面に何も表示されず、
                    // 「追加したのに反映されない」ように見えてしまっていたため、ここで拾って表示する。
                    if let error = profileManager.errorMessage {
                        faceCheckMessage = error
                        showingFaceCheckAlert = true
                        profileManager.errorMessage = nil
                    }
                } else {
                    faceCheckMessage = result.message ?? "顔が写っている写真を選んでください"
                    showingFaceCheckAlert = true
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
            nationality: nationality,
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
            replyTime: replyTime,
            boostExpiresAtString: base?.boostExpiresAtString,
            createdAtString: base?.createdAtString
        )
    }

    func save() {
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
            let suceeded = await profileManager.save(name: name, description: description, gender: gender, birthday: birthday, area: area, height: height, major: major, nationality: nationality ?? "", tagline: tagline, drinking: drinking, smoking: smoking, bodyType: bodyType, languages: Array(languages), replyPace: replyPace, replyTime: replyTime)
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

#Preview {
    ProfileEditView(profileManager: ProfileManager())
}

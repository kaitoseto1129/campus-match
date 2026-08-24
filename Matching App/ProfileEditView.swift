//
//  SwiftUIView.swift
//  Matching App
//

import SwiftUI
import PhotosUI
import Supabase

struct ProfileEditView: View {
    @ObservedObject var profileManager: ProfileManager
    /// 新規登録直後の必須項目入力(オンボーディング)として表示している場合はtrue。
    /// この場合はキャンセルできないようにする。
    var isOnboarding: Bool = false
    /// マイページの「やることリスト」から遷移した場合、開いた直後にその項目のセクションまで自動スクロールする。
    var initialFocusSectionId: String? = nil
    /// オンボーディング時、「保存」が成功した瞬間だけ呼ばれる。写真追加などの途中経過では呼ばれないため、
    /// 「保存を押していないのに次の画面(通知許可など)に進んでしまう」ことがない。
    var onOnboardingComplete: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State var name: String = ""
    @State var description: String = ""
    /// 「キャンセル」タップ時に未保存の変更があるか判定するための、読み込み直後の値。
    @State private var originalName: String = ""
    @State private var originalDescription: String = ""
    @State private var showingDiscardConfirm = false
    @State var gender: Gender? = nil
    @State var birthday: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    /// 誕生日は日付型の性質上「未入力」を表現できないため、実際に選んだかどうかを別に持つ。
    /// これがないと初期値(20歳)が入力済みに見えてしまう。
    @State var hasChosenBirthday: Bool = false
    @State var area: String = ""
    @State var city: String = ""
    private var areaLabel: String { area.isEmpty ? unselectedOption : (city.isEmpty ? area : "\(area) \(city)") }
    @State var height: Int? = nil
    @State var major: String = ""
    @State var nationalities: Set<String> = []
    @State var tagline: String = ""
    @State var drinking: String = unselectedOption
    @State var smoking: String = unselectedOption
    @State var bodyType: String = unselectedOption
    @State var languages: Set<String> = []
    @State var universityId: UUID? = nil
    @State var universityName: String = ""
    @State var pickerItem: PhotosPickerItem? = nil
    /// 直近でタップした写真スロット(0=メイン, 1〜3=サブ)。pickerItemが確定した時にどこへ入れるか判定するために使う。
    @State var pickerTargetSlot: Int = 0
    @State var showingSaveFailAlert : Bool = false
    @State var isSaving = false
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
    @State var showingUniversityPicker: Bool = false
    @State var showingChangePhotoPicker: Bool = false
    @State var draggingSlot: Int? = nil
    /// タップした写真の「変更する/削除する」メニューを出す対象スロット。
    @State var photoActionSlot: Int? = nil
    /// 「画像を変更する」で置き換える対象。新しい写真の登録が成功したら、この古い写真を削除する。
    @State var photoToReplace: ProfilePhoto? = nil

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
        // 初回登録では聞かず、あとから埋めてもらう項目。
        if missingLabel.contains("専攻") || missingLabel.contains("身長") { return "details" }
        if missingLabel.contains("話せる言語") { return "lifestyle" }
        return "basic"
    }

    static let minDescriptionLength = 50
    /// サブ写真の表示枠数(任意項目なので登録は必須ではない)。
    static let minSubPhotoCount = 2
    /// 必須なのはメイン写真1枚のみ。サブ写真は任意。
    static let minPhotoCount = 1
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

    /// サブ写真を「メインにする」際に、新規アップロード時(顔検出必須)と同じ基準を通す。
    /// 以前はここを素通りしていたため、顔が写っていない写真でも
    /// (先にサブ写真として登録さえしてしまえば)メイン写真に設定できてしまっていた。
    private func makeMainWithFaceCheck(_ target: ProfilePhoto) async {
        guard let url = target.url else {
            await profileManager.makeMain(photo: target)
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                faceCheckMessage = "この写真を読み込めませんでした。別の写真でお試しください。"
                showingFaceCheckAlert = true
                return
            }
            let result = await FaceDetector().checkFace(image: image)
            guard case .ok = result else {
                faceCheckMessage = result.message ?? "顔が写っている写真を選んでください"
                showingFaceCheckAlert = true
                return
            }
        } catch {
            faceCheckMessage = "写真の確認に失敗しました。もう一度お試しください。"
            showingFaceCheckAlert = true
            return
        }
        await profileManager.makeMain(photo: target)
    }

    var photosSection: some View {
        Group {
            Section("メイン写真(必須)") {
                if let mainPhoto = photo(forSlot: 0) {
                    editablePhotoCell(mainPhoto, slot: 0)
                        .frame(width: 100, height: 100)
                } else {
                    emptyPhotoSlot(label: "メイン写真を追加", slot: 0)
                        .frame(width: 100, height: 100)
                }
                Text("あなたの顔がはっきり写っている写真を選んでください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("サブ写真(任意・\(Self.minSubPhotoCount)枚まで)") {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                let subSlotHints = ["趣味の写真など", "全身の写真など"]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...Self.minSubPhotoCount, id: \.self) { slot in
                        if let subPhoto = photo(forSlot: slot) {
                            editablePhotoCell(subPhoto, slot: slot)
                        } else {
                            emptyPhotoSlot(label: slot - 1 < subSlotHints.count ? subSlotHints[slot - 1] : "サブ\(slot)", slot: slot)
                        }
                    }
                }
                Text("メインより先に、この\(Self.minSubPhotoCount)枚から登録しても大丈夫です。写真をドラッグすると並び替えられます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .id("photos")
    }
    func emptyPhotoSlot(label: String, slot: Int) -> some View {
        // 枠ごとに別々のPhotosPickerを持たせると、同じ選択状態を共有する複数インスタンスが
        // 干渉して選択画面が閉じても再度開いてしまう不具合があったため、タップしたスロットだけ
        // 記録しておき、画面全体で1つだけ持つPhotosPicker(showingChangePhotoPicker)を開く。
        Button {
            pickerTargetSlot = slot
            showingChangePhotoPicker = true
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .frame(height: 80)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text(LocalizedStringKey(label))
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                }
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let sourceSlot = items.first.flatMap(Int.init) else { return false }
            Task { await profileManager.swapPhotos(at: sourceSlot, and: slot) }
            return true
        }
    }
    func editablePhotoCell(_ photo: ProfilePhoto, slot: Int) -> some View {
        // .onTapGesture と .draggable を同じビューに載せると、ジェスチャー同士が競合して
        // ドラッグでの並び替えが反応しなくなることがあったため、タップはButtonにまとめる
        // (emptyPhotoSlotと同じ方式。Buttonのタップ認識はdraggableのドラッグ開始と衝突しにくい)。
        Button {
            photoActionSlot = slot
        } label: {
            ZStack(alignment: .topLeading) {
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
            }
            .frame(height: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(String(slot))
        .dropDestination(for: String.self) { items, _ in
            guard let sourceSlot = items.first.flatMap(Int.init) else { return false }
            Task { await profileManager.swapPhotos(at: sourceSlot, and: slot) }
            return true
        }
    }

    private func formRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(LocalizedStringKey(title))
                    .foregroundStyle(.primary)
                Spacer()
                Text(LocalizedStringKey(value))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .buttonStyle(.plain)
    }

    /// タイトルを常時表示のラベルにして、値だけをその場で編集できる行。
    /// (以前はプレースホルダーが入力すると消えてしまい、何の項目か分かりづらかった)
    private func labeledTextField(title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .foregroundStyle(.primary)
            Spacer()
            TextField(LocalizedStringKey(placeholder), text: text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    /// 必須項目。入力済みかどうかで行の見た目(チェック/未入力バッジ)を変える。
    private func requiredRow(title: String, value: String?, action: @escaping () -> Void) -> some View {
        let isFilled = !(value ?? "").isEmpty
        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isFilled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isFilled ? Color.brandTeal : Color(.systemGray3))
                Text(LocalizedStringKey(title))
                    .foregroundStyle(.primary)
                Spacer()
                if isFilled {
                    Text(LocalizedStringKey(value ?? ""))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("未入力")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brandOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandOrange.opacity(0.14), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .buttonStyle(.plain)
    }

    /// 必須項目だけを集めたセクション。オンボーディング中はここだけを見せる。
    var basicSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: name.isEmpty ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(name.isEmpty ? Color(.systemGray3) : Color.brandTeal)
                Text("ニックネーム")
                Spacer()
                TextField("未入力", text: $name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
            requiredRow(title: "誕生日", value: hasChosenBirthday ? birthdayLabel : nil) { showingBirthdayPicker = true }
            requiredRow(title: "性別", value: gender?.label) { showingGenderPicker = true }
            requiredRow(title: "居住地", value: area.isEmpty ? nil : areaLabel) { showingAreaPicker = true }
            requiredRow(title: "大学", value: universityName.isEmpty ? nil : universityName) {
                showingUniversityPicker = true
            }
        } header: {
            Label("基本情報(必須)", systemImage: "person.text.rectangle")
                .foregroundStyle(Color.brandPurple)
        }
        .id("basic")
    }

    /// あとから設定できる任意項目。オンボーディング中は表示せず、
    /// マイページの「やることリスト」から後で埋めてもらう。
    var optionalDetailsSection: some View {
        Section {
            labeledTextField(title: "専攻", text: $major, placeholder: "未入力")
            formRow(title: "身長", value: height.map { "\($0)cm" } ?? "未設定") { showingHeightPicker = true }
            formRow(title: "国籍(複数選択可)", value: nationalities.isEmpty ? "未設定" : nationalities.sorted().joined(separator: "・")) {
                showingNationalityPicker = true
            }
        } header: {
            Label("くわしいプロフィール(任意)", systemImage: "sparkles")
                .foregroundStyle(Color.brandPurple)
        }
        .id("details")
    }

    private var birthdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.currentLocale
        formatter.dateStyle = .long
        return formatter.string(from: birthday)
    }

    var lifestyleSection: some View {
        Section("ライフスタイル(任意)") {
            Picker("お酒", selection: $drinking) {
                ForEach(drinkingOptions, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
            }
            Picker("タバコ", selection: $smoking) {
                ForEach(smokingOptions, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
            }
            Picker("体型", selection: $bodyType) {
                ForEach(bodyTypeOptions, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
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
                    .foregroundStyle(description.count >= Self.minDescriptionLength ? .secondary : Color.brandPurple)
            }
        }
        .id("about")
    }
    /// 必須項目の充足状況。オンボーディングの進捗バーに使う。
    private var requiredItems: [(label: String, isFilled: Bool)] {
        [
            ("メイン写真", photo(forSlot: 0) != nil),
            ("ニックネーム", !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
            ("誕生日", hasChosenBirthday),
            ("性別", gender != nil),
            ("居住地", !area.isEmpty),
            ("大学", universityId != nil),
            ("自己紹介", description.count >= Self.minDescriptionLength)
        ]
    }
    private var filledRequiredCount: Int { requiredItems.filter(\.isFilled).count }
    private var requiredProgress: Double {
        guard !requiredItems.isEmpty else { return 1 }
        return Double(filledRequiredCount) / Double(requiredItems.count)
    }

    /// 登録に必要な項目が、あといくつ残っているかをひと目で分かるようにする。
    private var onboardingProgressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("あと\(requiredItems.count - filledRequiredCount)項目で完了!")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(filledRequiredCount) / \(requiredItems.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brandPurple)
            }
            ProgressView(value: requiredProgress)
                .tint(Color.brandPurple)
                .animation(.snappy, value: requiredProgress)
            Text("ここで入力するのは必須項目だけです。くわしいプロフィールは登録後にゆっくり追加できます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    var body: some View {
        // 巨大な修飾子チェーンをそのまま1つの式にすると型チェックがタイムアウトするため、
        // AnyViewで一度型を確定させて式を分割している。
        let content = AnyView(
        NavigationStack {
            ZStack {
                Color.appListBackground.ignoresSafeArea()
                ScrollViewReader { proxy in
                    Form {
                        if isOnboarding {
                            Section { onboardingProgressHeader }
                        }
                        photosSection
                        basicSection
                        aboutSection
                        // オンボーディング中は必須項目だけに絞り、任意項目は後から埋めてもらう。
                        if !isOnboarding {
                            optionalDetailsSection
                            lifestyleSection
                            taglineSection
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        if let target = initialFocusSectionId {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo(target, anchor: .top) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text(isOnboarding ? "プロフィール登録" : "プロフィール編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction){
                        Button("キャンセル") {
                            if name != originalName || description != originalDescription {
                                showingDiscardConfirm = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("プレビュー") { showingPreview = true }
                        .font(.subheadline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("保存") {
                            save()
                        }
                    }
                }
            }
        }
        .confirmationDialog("編集内容を破棄しますか?", isPresented: $showingDiscardConfirm, titleVisibility: .visible) {
            Button("破棄する", role: .destructive) { dismiss() }
            Button("編集を続ける", role: .cancel) {}
        }
        // 大学はサインアップ時に、登録した大学メールのドメインからサーバー側で自動設定される。
        // ただしプロフィール本体より後に大学名の取得が完了することがあり、その場合
        // onAppearの時点では名前が空で「選択してください」と表示され、
        // 実際には紐づいているのに未選択に見えてしまっていた。読み込み完了時にも反映する。
        .onChange(of: profileManager.university?.id) { _, _ in
            if let university = profileManager.university {
                universityId = university.id
                universityName = university.name
            }
        }
        .onAppear {
            if let profile = profileManager.profile {
                self.name = profile.name
                self.description = profile.description ?? ""
                self.originalName = profile.name
                self.originalDescription = profile.description ?? ""
                self.gender = profile.gender
                self.hasChosenBirthday = profile.birthday != nil
                self.birthday = profile.birthday ?? (Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date())
                self.area = profile.area
                self.city = profile.city ?? ""
                self.height = profile.height
                self.major = profile.major ?? ""
                self.nationalities = Set(profile.nationalities)
                self.tagline = profile.tagline ?? ""
                self.drinking = profile.drinking ?? unselectedOption
                self.smoking = profile.smoking ?? unselectedOption
                self.bodyType = profile.bodyType ?? unselectedOption
                self.languages = Set(profile.languages)
                self.universityId = profile.universityId
                self.universityName = profileManager.university?.name ?? ""
            }
        }
        .onChange(of: pickerItem) {oldValue, newValue in
            let targetSlot = pickerTargetSlot
            // 「画像を変更する」経由の場合だけ設定されている、置き換え対象の古い写真。
            // 後続の別の追加操作に誤って引き継がれないよう、ここで一旦取り出してリセットする。
            let oldPhotoToReplace = photoToReplace
            photoToReplace = nil
            Task {
                guard let newValue else { return }
                let image: UIImage
                do {
                    // 以前はここで失敗すると(try?で握りつぶして)何も表示せず終わっていたため、
                    // 「写真を選んでも何も起きない」ように見えて何度も選び直す原因になっていた。
                    guard let data = try await newValue.loadTransferable(type: Data.self), let loaded = UIImage(data: data) else {
                        pickerItem = nil
                        faceCheckMessage = "この写真を読み込めませんでした。別の写真でお試しください。"
                        showingFaceCheckAlert = true
                        return
                    }
                    image = loaded
                } catch {
                    pickerItem = nil
                    faceCheckMessage = "写真の読み込みに失敗しました。もう一度お試しください。"
                    showingFaceCheckAlert = true
                    print("photo load error: \(error)")
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
                // 置き換えの場合は先に古い写真を消してから登録する。
                // (先に新しい写真を同じスロットへ追加すると、一時的に同じスロットの写真が2枚になり、
                // 削除時の並び直し処理でスロットがズレてしまうため)
                if let oldPhotoToReplace {
                    let deleted = await profileManager.deletePhoto(photo: oldPhotoToReplace)
                    guard deleted else {
                        faceCheckMessage = profileManager.errorMessage ?? "写真の入れ替えに失敗しました。もう一度お試しください。"
                        showingFaceCheckAlert = true
                        profileManager.errorMessage = nil
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
        )
        return content
        .fullScreenCover(item: $cropperImage) { wrapper in
            PhotoCropperView(image: wrapper.image) { result in
                cropperContinuation?.resume(returning: result)
                cropperContinuation = nil
                cropperImage = nil
            }
        }
        .sheet(isPresented: $showingBirthdayPicker) {
            BirthdayPickerView(birthday: $birthday) { hasChosenBirthday = true }
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguageMultiSelectView(selected: $languages)
        }
        .sheet(isPresented: $showingNationalityPicker) {
            NationalityMultiSelectView(selected: $nationalities)
        }
        .sheet(isPresented: $showingAreaPicker) {
            ResidencePickerView(area: $area, city: $city)
        }
        .confirmationDialog("性別", isPresented: $showingGenderPicker, titleVisibility: .visible) {
            Button(LocalizedStringKey(Gender.male.label)) { gender = .male }
            Button(LocalizedStringKey(Gender.female.label)) { gender = .female }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showingHeightPicker) {
            HeightPickerView(height: $height)
        }
        .sheet(isPresented: $showingUniversityPicker) {
            UniversityPickerView(universityId: $universityId, universityName: $universityName, area: area)
        }
        .confirmationDialog("写真を編集", isPresented: Binding(
            get: { photoActionSlot != nil },
            set: { if !$0 { photoActionSlot = nil } }
        ), titleVisibility: .visible) {
            Button("画像を変更する") {
                if let slot = photoActionSlot {
                    pickerTargetSlot = slot
                    photoToReplace = photo(forSlot: slot)
                    showingChangePhotoPicker = true
                }
            }
            if let slot = photoActionSlot, slot != 0, let target = photo(forSlot: slot) {
                Button("メインにする") {
                    Task { await makeMainWithFaceCheck(target) }
                }
            }
            if let slot = photoActionSlot, let target = photo(forSlot: slot) {
                Button("削除する", role: .destructive) {
                    Task { await profileManager.deletePhoto(photo: target) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingChangePhotoPicker, selection: $pickerItem, matching: .images)
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
                    HStack(spacing: 10) {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(Color.brandPurple)
                        Text("これは他のユーザーから見たプレビューです")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .navigationTitle("プレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { showingPreview = false }
                            .bold()
                            .foregroundStyle(Color.brandPurple)
                    }
                }
            }
        }
        .alert("写真を追加できません", isPresented: $showingFaceCheckAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(faceCheckMessage))
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
            Text(LocalizedStringKey(validationMessage))
        }
    }

    /// 保存前のプレビュー表示用に、現在編集中の値から一時的なProfileを組み立てる。
    private var draftPreviewProfile: Profile {
        let base = profileManager.profile
        return Profile(
            id: base?.id ?? UUID(),
            universityId: universityId ?? base?.universityId ?? UUID(),
            name: name,
            description: description,
            gender: gender,
            birthday: birthday,
            profileImageUrlString: base?.profileImageUrlString,
            area: area,
            city: city.isEmpty ? nil : city,
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
            membershipTier: base?.membershipTier,
            hobbyCards: base?.hobbyCards ?? [],
            boostExpiresAtString: base?.boostExpiresAtString,
            createdAtString: base?.createdAtString
        )
    }

    /// マッチングアプリとしてApp Storeの審査要件(17+の年齢制限カテゴリ)を満たすため、
    /// 18歳未満のユーザーはプロフィールを完成させられないようにする。
    static let minimumAge = 18

    func save() {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "ニックネームを入力してください"
            showingValidationAlert = true
            return
        }
        let age = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        if age < Self.minimumAge {
            validationMessage = "このアプリは\(Self.minimumAge)歳以上の方のみご利用いただけます"
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
        if photo(forSlot: 0) == nil {
            validationMessage = "メイン写真を追加してください(サブ写真は任意です)"
            showingValidationAlert = true
            return
        }
        guard hasChosenBirthday else {
            validationMessage = "誕生日を選択してください"
            showingValidationAlert = true
            return
        }
        guard let gender else {
            validationMessage = "性別を選択してください"
            showingValidationAlert = true
            return
        }
        guard !area.isEmpty else {
            validationMessage = "居住地を選択してください"
            showingValidationAlert = true
            return
        }
        guard let universityId else {
            validationMessage = "大学を選択してください"
            showingValidationAlert = true
            return
        }
        guard !isSaving else { return }
        isSaving = true
        Task {
            let suceeded = await profileManager.save(name: name, description: description, gender: gender, birthday: birthday, area: area, city: city.isEmpty ? nil : city, height: height, major: major, nationalities: Array(nationalities), tagline: tagline, drinking: drinking, smoking: smoking, bodyType: bodyType, languages: Array(languages), universityId: universityId)
            isSaving = false
            if suceeded {
                dismiss()
                await profileManager.load()
                if isOnboarding {
                    onOnboardingComplete?()
                }
            } else {
                showingSaveFailAlert = true
            }
        }
    }
}

/// 誕生日をカレンダーグリッドではなく、年・月・日のホイールで手早く選べるようにした画面。
struct BirthdayPickerView: View {
    @Binding var birthday: Date
    /// 「決定」を押して実際に選んだことを呼び出し元に伝える(初期値との区別に使う)。
    var onConfirm: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date

    init(birthday: Binding<Date>, onConfirm: (() -> Void)? = nil) {
        self._birthday = birthday
        self.onConfirm = onConfirm
        self._draft = State(initialValue: birthday.wrappedValue)
    }

    /// 18歳未満になる日付は選べないようにする(アプリの年齢制限に合わせた選択範囲)。
    private var maximumBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -ProfileEditView.minimumAge, to: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            DatePicker("誕生日", selection: $draft, in: ...maximumBirthday, displayedComponents: .date)
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
                        onConfirm?()
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
                                        .foregroundStyle(Color.brandPurple)
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
                                        .foregroundStyle(Color.brandPurple)
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
    @Binding var city: String
    @Environment(\.dismiss) private var dismiss
    @State private var country: String
    @State private var searchText = ""
    /// 州や「その他の国」を直接この画面で選ぶ場合、タップ即確定ではなく保存ボタンで確定する。
    @State private var pendingArea: String? = nil

    init(area: Binding<String>, city: Binding<String>) {
        self._area = area
        self._city = city
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
                            city = ""
                        }
                    } label: {
                        HStack {
                            Text("国")
                            Spacer()
                            Text(country).foregroundStyle(Color.brandPurple)
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
                                    PrefectureListView(options: region.prefectures, title: region.name, area: $area, city: $city) { dismiss() }
                                } label: {
                                    HStack {
                                        Text(region.name)
                                        Spacer()
                                        if region.prefectures.contains(area) {
                                            Text(city.isEmpty ? area : city).font(.caption).foregroundStyle(Color.brandPurple)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Section {
                            ForEach(prefectures.filter { $0.contains(searchText) }, id: \.self) { prefecture in
                                if let municipalities = japanMunicipalities[prefecture] {
                                    NavigationLink {
                                        MunicipalityListView(options: municipalities, prefecture: prefecture, area: $area, city: $city) { dismiss() }
                                    } label: {
                                        HStack {
                                            Text(prefecture).foregroundStyle(.primary)
                                            Spacer()
                                            if area == prefecture {
                                                Text(city).font(.caption).foregroundStyle(Color.brandPurple)
                                            }
                                        }
                                    }
                                } else {
                                    selectableRow(prefecture)
                                }
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
                            pendingArea = country
                        } label: {
                            HStack {
                                Text(country)
                                Spacer()
                                if pendingArea == country || (pendingArea == nil && area == country) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
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
                if pendingArea != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if let pendingArea {
                                area = pendingArea
                                city = ""
                            }
                            dismiss()
                        }
                        .bold()
                    }
                }
            }
        }
    }

    private func selectableRow(_ value: String) -> some View {
        Button {
            pendingArea = value
        } label: {
            HStack {
                Text(value).foregroundStyle(.primary)
                Spacer()
                if pendingArea == value || (pendingArea == nil && area == value) {
                    Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
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
                                Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
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
    @Binding var city: String
    var onSelect: () -> Void
    @State private var searchText = ""
    /// タップしただけで即座に閉じてしまうと選び間違いに気づきにくいため、
    /// いったん選択状態にしてから右上の「保存」で確定する形にしている。
    @State private var pendingSelection: String? = nil

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
                    if let municipalities = japanMunicipalities[option] {
                        NavigationLink {
                            MunicipalityListView(options: municipalities, prefecture: option, area: $area, city: $city, onSelect: onSelect)
                        } label: {
                            HStack {
                                Text(option).foregroundStyle(.primary)
                                Spacer()
                                if area == option {
                                    Text(city).font(.caption).foregroundStyle(Color.brandPurple)
                                }
                            }
                        }
                    } else {
                        Button {
                            pendingSelection = option
                        } label: {
                            HStack {
                                Text(option).foregroundStyle(.primary)
                                Spacer()
                                if pendingSelection == option || (pendingSelection == nil && area == option) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if let pendingSelection {
                        area = pendingSelection
                        city = ""
                    }
                    onSelect()
                }
                .disabled(pendingSelection == nil)
                .bold()
            }
        }
    }
}

/// 都道府県よりも詳細な市区町村(政令指定都市の区・東京23区など)を選ぶ画面。
/// 「〇〇全体」を選べば市区町村を指定せず、都道府県単位のままにできる。
private struct MunicipalityListView: View {
    let options: [String]
    let prefecture: String
    @Binding var area: String
    @Binding var city: String
    var onSelect: () -> Void
    @State private var searchText = ""
    /// nilは「未選択」、空文字は「(市区町村を指定せず)県全体」を表す。
    @State private var pendingCity: String?? = nil

    private var filtered: [String] {
        searchText.isEmpty ? options : options.filter { $0.contains(searchText) }
    }
    private var currentSelection: String? {
        pendingCity ?? (area == prefecture ? city : nil)
    }

    var body: some View {
        Form {
            Section {
                Button {
                    pendingCity = .some("")
                } label: {
                    HStack {
                        Text("\(prefecture)全体").foregroundStyle(.primary)
                        Spacer()
                        if currentSelection == "" {
                            Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                        }
                    }
                }
            }
            Section {
                TextField("市区町村を検索", text: $searchText)
            }
            Section {
                ForEach(filtered, id: \.self) { option in
                    Button {
                        pendingCity = .some(option)
                    } label: {
                        HStack {
                            Text(option).foregroundStyle(.primary)
                            Spacer()
                            if currentSelection == option {
                                Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(prefecture)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    area = prefecture
                    city = currentSelection ?? ""
                    onSelect()
                }
                .disabled(pendingCity == nil)
                .bold()
            }
        }
    }
}

/// 大学の選択画面。選んだ居住地(都道府県/州)にある大学を優先的に表示しつつ、検索も常にできるようにする。
struct UniversityPickerView: View {
    @Binding var universityId: UUID?
    @Binding var universityName: String
    let area: String
    @Environment(\.dismiss) private var dismiss
    @State private var universities: [University] = []
    @State private var searchText = ""
    @State private var mismatchTarget: University? = nil

    private var relevantUniversities: [University] {
        let matches = universities.filter { $0.prefecture == area }
        return matches.isEmpty ? universities : matches
    }
    private var filtered: [University] {
        searchText.isEmpty ? relevantUniversities : universities.filter { $0.name.contains(searchText) }
    }
    private var isFilteredByArea: Bool {
        searchText.isEmpty && relevantUniversities.count < universities.count
    }

    /// 登録済みの大学メールアドレスのドメインと一致するかを確認するため、
    /// サブドメイン発行の大学(例:早稲田の@ruri.waseda.jp)にも対応した判定にしている(AuthViewと同じ考え方)。
    private func matchesRegisteredEmail(_ university: University) -> Bool {
        guard let email = supabase().auth.currentUser?.email?.lowercased() else { return true }
        let d = university.domain.lowercased()
        return email.hasSuffix("@\(d)") || email.hasSuffix(".\(d)")
    }

    private func select(_ university: University) {
        if matchesRegisteredEmail(university) {
            universityId = university.id
            universityName = university.name
            dismiss()
        } else {
            mismatchTarget = university
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("大学名で検索", text: $searchText)
                }
                if isFilteredByArea {
                    Section {
                        Text("居住地(\(area))に合わせて絞り込んでいます。他の大学は検索してください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(filtered) { university in
                        Button {
                            select(university)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(university.name)
                                        .foregroundStyle(.primary)
                                    Text(university.country)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if universityId == university.id {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("大学")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .task {
                await load()
            }
            .confirmationDialog(
                "登録したメールアドレスとは異なる大学です",
                isPresented: Binding(get: { mismatchTarget != nil }, set: { if !$0 { mismatchTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button("それでも選択する") {
                    if let mismatchTarget {
                        universityId = mismatchTarget.id
                        universityName = mismatchTarget.name
                    }
                    self.mismatchTarget = nil
                    dismiss()
                }
                Button("キャンセル", role: .cancel) { mismatchTarget = nil }
            } message: {
                Text("登録に使ったメールアドレスのドメインと、選んだ大学のメールドメインが一致していません。誤って別の大学を選んでいないか確認してください。")
            }
        }
    }

    private func load() async {
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

#Preview {
    ProfileEditView(profileManager: ProfileManager())
}

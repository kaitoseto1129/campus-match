//
//  SwiftUIView.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/08/02.
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @ObservedObject var profileManager: ProfileManager
    /// 新規登録直後の必須項目入力(オンボーディング)として表示している場合はtrue。
    /// この場合はキャンセルできないようにする。
    var isOnboarding: Bool = false
    @Environment(\.dismiss) var dismiss
    @State var name: String = ""
    @State var description: String = ""
    @State var gender: Gender = .male
    @State var birthday: Date = Date()
    @State var area: String = ""
    @State var height: Int? = nil
    @State var major: String = ""
    @State var nationality: String? = nil
    @State var tagline: String = ""
    @State var drinking: String = drinkingOptions[0]
    @State var smoking: String = smokingOptions[0]
    @State var bodyType: String = bodyTypeOptions[0]
    @State var languages: Set<String> = ["日本語"]
    @State var replyPace: String = replyPaceOptions[0]
    @State var replyTime: String = replyTimeOptions[0]
    @State var pickerItem: PhotosPickerItem? = nil
    @State var showingSaveFailAlert : Bool = false
    @State var faceCheckMessage: String = ""
    @State var showingFaceCheckAlert: Bool = false
    @State var validationMessage: String = ""
    @State var showingValidationAlert: Bool = false

    static let minDescriptionLength = 100
    static let minPhotoCount = 4 // メイン1枚 + サブ3枚
    static let descriptionTemplate = "【仕事】\n\n【趣味】\n\n【好きな食べ物】\n"
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
    }
    var photosSection: some View {
        Section {
            let columns = Array(repeating: GridItem(.flexible(),spacing: 10),count: 4)
            LazyVGrid(columns: columns, spacing: 10){
                ForEach(profileManager.photos) {photo in
                    editablePhotoCell(photo)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(height: 80)
                        .overlay {
                            VStack(spacing:6) {
                                Image(systemName:"plus")
                                    .font(.title2)
                                Text("追加する")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
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
//            .frame(maxWidth: .infinity)
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
            DatePicker("誕生日", selection: $birthday, in:...Date(), displayedComponents:.date)
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
            Picker("国籍", selection: $nationality) {
                Text("選択してください").tag(String?.none)
                ForEach(nationalities, id: \.self) { nation in
                    Text(nation).tag(String?.some(nation))
                }
            }
        }
    }
    var lifestyleSection: some View {
        Section("ライフスタイル") {
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
            VStack(alignment: .leading, spacing: 6) {
                Text("話せる言語(複数選択可)")
                ForEach(languageOptions, id: \.self) { language in
                    Button {
                        if languages.contains(language) {
                            languages.remove(language)
                        } else {
                            languages.insert(language)
                        }
                    } label: {
                        HStack {
                            Text(language)
                                .foregroundStyle(.primary)
                            Spacer()
                            if languages.contains(language) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandRed)
                            }
                        }
                    }
                }
            }
        }
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
                Spacer()
                Text("\(description.count) / \(Self.minDescriptionLength)文字以上")
                    .font(.caption)
                    .foregroundStyle(description.count >= Self.minDescriptionLength ? .secondary : Color.brandRed)
            }
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                photosSection
                taglineSection
                basicSection
                lifestyleSection
                aboutSection
            }
            
            .navigationTitle(Text(isOnboarding ? "プロフィールを完成させましょう" : "プロフィール編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction){
                        Button("キャンセル"){dismiss()}
                    }
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
                self.birthday = profile.birthday ?? Date()
                self.area = profile.area
                self.height = profile.height
                self.major = profile.major ?? ""
                self.nationality = profile.nationality
                self.tagline = profile.tagline ?? ""
                self.drinking = profile.drinking ?? drinkingOptions[0]
                self.smoking = profile.smoking ?? smokingOptions[0]
                self.bodyType = profile.bodyType ?? bodyTypeOptions[0]
                self.languages = profile.languages.isEmpty ? ["日本語"] : Set(profile.languages)
                self.replyPace = profile.replyPace ?? replyPaceOptions[0]
                self.replyTime = profile.replyTime ?? replyTimeOptions[0]
            }
        }
        .onChange(of: pickerItem) {oldValue, newValue in
            Task {
                guard let newValue, let data = try? await newValue.loadTransferable(type: Data.self), let image = UIImage(data: data) else {return}
                let result = await FaceDetector().checkFace(image: image)

                        if case .ok = result {
                            await profileManager.addPhoto(image: image)
                        } else {
                            faceCheckMessage = result.message ?? "顔が写っている写真を選んでください"
                            showingFaceCheckAlert = true
                            
                        }
                pickerItem = nil
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
    func save() {
        if description.count < Self.minDescriptionLength {
            validationMessage = "自己紹介文は\(Self.minDescriptionLength)文字以上入力してください"
            showingValidationAlert = true
            return
        }
        if profileManager.photos.count < Self.minPhotoCount {
            validationMessage = "写真をメイン1枚+サブ3枚以上、合計\(Self.minPhotoCount)枚以上追加してください"
            showingValidationAlert = true
            return
        }
        guard let height else {
            validationMessage = "身長を選択してください"
            showingValidationAlert = true
            return
        }
        guard let nationality else {
            validationMessage = "国籍を選択してください"
            showingValidationAlert = true
            return
        }
        Task {
            let suceeded = await profileManager.save(name: name, description: description, gender: gender, birthday: birthday, area: area, height: height, major: major, nationality: nationality, tagline: tagline, drinking: drinking, smoking: smoking, bodyType: bodyType, languages: Array(languages), replyPace: replyPace, replyTime: replyTime)
            if suceeded {
                dismiss()
                await profileManager.load()
            } else {
                showingSaveFailAlert = true
            }
        }
    }
}

#Preview {
    ProfileEditView(profileManager: ProfileManager())
}

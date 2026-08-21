//
//  ProfileView.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/08/01.
//

import SwiftUI
import PhotosUI
extension Color {
    /// アプリのテーマカラー。アプリアイコン(紫→ピンクのグラデーション)に合わせている。
    /// 以前は水色(brandBlue)だったが、アイコンの配色に統一するためbrandPurpleに変更した。
    static let brandPurple = Color(red: 0.56, green: 0.47, blue: 0.92)
    static let brandNavy = Color(red: 0.10, green: 0.18, blue: 0.40)
    static let brandPink = Color(red: 0.93, green: 0.56, blue: 0.75)
    static let brandTeal = Color(red: 0.20, green: 0.75, blue: 0.68)
    static let brandOrange = Color(red: 0.96, green: 0.62, blue: 0.28)

    /// アプリアイコンと同じ紫→ピンクのグラデーション。
    static let brandGradient = LinearGradient(
        colors: [Color.brandPurple, Color.brandPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appListBackground = LinearGradient(
        colors: [Color.brandPurple.opacity(0.14), Color.brandPink.opacity(0.10), Color(.systemGroupedBackground)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 探す画面のカードなどに使う、ユーザーIDから決まる一貫したパステルカラー。
    /// 彩度・明度を抑えめにして「カラフルだけど派手すぎない」バリエーションを出す。
    static func pastelAccent(for id: UUID) -> Color {
        var hasher = Hasher()
        hasher.combine(id)
        let hue = Double(abs(hasher.finalize()) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.88)
    }
}

struct ProfileView: View {
    @StateObject var profileManager: ProfileManager
    @EnvironmentObject private var tabRouter: TabRouter
    @State var showEditSheet: Bool = false
    @State private var showingMainPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var faceCheckMessage: String = ""
    @State private var showingFaceCheckAlert = false
    @State private var cropperImage: IdentifiableImage? = nil
    @State private var cropperContinuation: CheckedContinuation<UIImage?, Never>? = nil

    private func presentCropper(for image: UIImage) async -> UIImage? {
        await withCheckedContinuation { continuation in
            cropperContinuation = continuation
            cropperImage = IdentifiableImage(image: image)
        }
    }

    var editButton: some View {
        Button {
            showEditSheet = true
        } label: {
            HStack {
                Image(systemName: "square.and.pencil")
                Text("編集する")
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.brandPurple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    var body : some View {
        ProfileDisplayView(
            profile: profileManager.profile,
            university: profileManager.university,
            photos: profileManager.photos,
            showsPhotoEditHint: true,
            onTapMainPhoto: { showingMainPhotoPicker = true }
        ) {
            editButton
        }
        .task {
            await profileManager
                .load()
        }
        .onAppear {
            // タブバーが編集ボタンの上に覆いかぶさって隠してしまっていたため、他の詳細画面同様に隠す。
            tabRouter.pushDetailScreen()
        }
        .onDisappear {
            tabRouter.popDetailScreen()
        }
        .sheet(isPresented: $showEditSheet){
            ProfileEditView(profileManager: profileManager)
        }
        .photosPicker(isPresented: $showingMainPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newValue in
            Task {
                guard let newValue else { return }
                let image: UIImage
                do {
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
                guard let croppedImage = await presentCropper(for: image) else { return }
                let result = await FaceDetector().checkFace(image: croppedImage)
                if case .ok = result {
                    await profileManager.changeMainPhoto(image: croppedImage)
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
        .alert("写真を変更できません", isPresented: $showingFaceCheckAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(faceCheckMessage))
        }
    }
}

#Preview {
    ProfileView(profileManager: .preview)
//    IconImage(url: URL(string: */"https://pbs.twimg.com/media/GpV8u2FbYAIJIdY.jpg"),size: 40)
}

struct IconImage: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        Group {
            if url == nil {
                placeholder
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                            .overlay { ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
    var placeholder: some View {
        Circle()
            .fill(Color(.systemGray6))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.4, height: size * 0.4)
                    .foregroundStyle(Color(.systemGray3))
            }
    }
}

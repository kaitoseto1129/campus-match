//
//  ProfileView.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/08/01.
//

import SwiftUI
import PhotosUI
extension Color {
    static let brandRed = Color(red: 0.96, green: 0.42, blue: 0.44)
    static let brandNavy = Color(red: 0.10, green: 0.18, blue: 0.40)
    static let brandPink = Color(red: 0.99, green: 0.55, blue: 0.62)
    static let brandTeal = Color(red: 0.20, green: 0.75, blue: 0.68)
    static let brandOrange = Color(red: 0.96, green: 0.62, blue: 0.28)
    static let brandBlue = Color(red: 0.28, green: 0.52, blue: 0.93)

    static let brandGradient = LinearGradient(
        colors: [Color.brandPink.opacity(0.9), Color.brandRed.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appListBackground = LinearGradient(
        colors: [Color.brandPink.opacity(0.12), Color.brandTeal.opacity(0.07), Color(.systemGroupedBackground)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct ProfileView: View {
    @StateObject var profileManager: ProfileManager
    @State var showEditSheet: Bool = false
    @State private var showingMainPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var faceCheckMessage: String = ""
    @State private var showingFaceCheckAlert = false

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
            .background(Color.brandRed)
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
        .sheet(isPresented: $showEditSheet){
            ProfileEditView(profileManager: profileManager)
        }
        .photosPicker(isPresented: $showingMainPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newValue in
            Task {
                guard let newValue,
                      let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                let result = await FaceDetector().checkFace(image: image)
                if case .ok = result {
                    await profileManager.changeMainPhoto(image: image)
                } else {
                    faceCheckMessage = result.message ?? "顔が写っている写真を選んでください"
                    showingFaceCheckAlert = true
                }
                pickerItem = nil
            }
        }
        .alert("写真を変更できません", isPresented: $showingFaceCheckAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(faceCheckMessage)
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

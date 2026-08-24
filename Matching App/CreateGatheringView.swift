//
//  CreateGatheringView.swift
//  Matching App
//

import SwiftUI
import PhotosUI

struct CreateGatheringView: View {
    @ObservedObject var manager: GatheringManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var scheduledAt = Date().addingTimeInterval(60 * 60 * 3)
    @State private var capacity = 4
    @State private var category = gatheringCategoryOptions[0]
    @State private var durationHours = 2
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSubmitting = false
    @State private var showingErrorAlert = false

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && scheduledAt > Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("何をしますか?") {
                    TextField("例: 駅前のカフェでご飯行きませんか", text: $title)
                    TextField("補足があれば(任意)", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(gatheringCategoryOptions, id: \.self) { option in
                            Text(LocalizedStringKey(option)).tag(option)
                        }
                    }
                }
                Section("写真(任意)") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            HStack {
                                Image(systemName: "photo")
                                Text("写真を追加")
                            }
                            .foregroundStyle(Color.brandPurple)
                        }
                    }
                    if selectedImage != nil {
                        Button(role: .destructive) {
                            selectedImage = nil
                            pickerItem = nil
                        } label: {
                            Text("写真を削除")
                        }
                    }
                }
                Section("いつ・どこで?") {
                    DatePicker("日時", selection: $scheduledAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Stepper(value: $durationHours, in: 1...6) {
                        HStack {
                            Text("所要時間の目安")
                            Spacer()
                            Text(String.appLocalized("だいたい%lld時間", durationHours))
                                .foregroundStyle(Color.brandPurple)
                                .bold()
                        }
                    }
                    TextField("場所(駅名やお店の名前など)", text: $location)
                }
                Section("人数") {
                    Stepper(value: $capacity, in: 2...8) {
                        HStack {
                            Text("自分を含めて")
                            Spacer()
                            Text(String.appLocalized("%lld人まで", capacity))
                                .foregroundStyle(Color.brandPurple)
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("集まりを募集する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSubmitting = true
                            let succeeded = await manager.create(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                                scheduledAt: scheduledAt,
                                capacity: capacity,
                                category: category,
                                durationHours: durationHours,
                                image: selectedImage
                            )
                            isSubmitting = false
                            if succeeded {
                                dismiss()
                            } else {
                                showingErrorAlert = true
                            }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("募集する").bold()
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .alert("募集できませんでした", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("通信環境をご確認のうえ、もう一度お試しください。")
            }
            .onChange(of: pickerItem) { _, newValue in
                Task {
                    guard let newValue, let data = try? await newValue.loadTransferable(type: Data.self) else { return }
                    selectedImage = UIImage(data: data)
                }
            }
        }
    }
}

#Preview {
    CreateGatheringView(manager: GatheringManager())
}

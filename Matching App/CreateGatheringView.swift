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
    @State private var hasDeadline = false
    @State private var deadlineAt = Date().addingTimeInterval(60 * 60 * 2)
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSubmitting = false
    @State private var showingErrorAlert = false

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && scheduledAt > Date()
            && selectedImage != nil
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
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(16 / 9, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // 一覧では16:9のサムネイルとして出るので、選ぶ段階から同じ形で見せる。
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title2)
                                    Text("写真を追加")
                                        .font(.subheadline.bold())
                                }
                                .foregroundStyle(Color.brandPurple)
                            }
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    if selectedImage != nil {
                        Button(role: .destructive) {
                            selectedImage = nil
                            pickerItem = nil
                        } label: {
                            Text("写真を選び直す")
                        }
                    }
                } header: {
                    Text("写真")
                } footer: {
                    Text("一覧では写真が大きく表示されます。どんな集まりか伝わる1枚を選んでください。")
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
                Section {
                    Toggle("応募の締切を設ける", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("締切日時", selection: $deadlineAt, in: Date()...scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    }
                } footer: {
                    Text("締切を過ぎると応募できなくなります。設定した場合は締切の到来を通知でお知らせします。")
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
                    .accessibilityIdentifier("closeCreateGatheringButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let image = selectedImage else { return }
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
                                deadlineAt: hasDeadline ? deadlineAt : nil,
                                image: image
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
            .onChange(of: scheduledAt) { _, newValue in
                // 締切のDatePickerはDate()...scheduledAtの範囲を取るため、開催日時を
                // 締切より前に変更されると範囲が壊れてしまう。締切側を自動で追従させる。
                if deadlineAt > newValue { deadlineAt = newValue }
            }
        }
    }
}

#Preview {
    CreateGatheringView(manager: GatheringManager())
}

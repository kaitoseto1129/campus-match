//
//  HobbyCardPickerView.swift
//  Matching App
//

import SwiftUI

/// 趣味カードをカテゴリごとに選ぶ画面。マイページの「趣味カードを追加する」から開く。
struct HobbyCardPickerView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var isSaving = false
    @State private var showingFailedAlert = false

    static let maxSelection = 10

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appListBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("あてはまる趣味カードを選ぶと、プロフィールに表示されて共通の話題が見つけやすくなります(最大\(Self.maxSelection)個)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(HobbyCategory.allCases) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 8, height: 8)
                                    Text(LocalizedStringKey(category.rawValue))
                                        .font(.subheadline.bold())
                                }
                                FlowLayout(spacing: 8) {
                                    ForEach(HobbyCard.catalog.filter { $0.category == category }) { card in
                                        Button {
                                            toggle(card)
                                        } label: {
                                            HobbyCardChip(card: card, isSelected: selected.contains(card.id))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("趣味カード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(selected.count) / \(Self.maxSelection)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                selected = Set(profileManager.profile?.hobbyCards ?? [])
            }
            .alert("保存に失敗しました", isPresented: $showingFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("通信環境を確認してもう一度お試しください。")
            }
        }
    }

    private func toggle(_ card: HobbyCard) {
        if selected.contains(card.id) {
            selected.remove(card.id)
        } else if selected.count < Self.maxSelection {
            selected.insert(card.id)
        }
    }

    private func save() async {
        isSaving = true
        // カタログ順に整えてから保存し、どの端末で見ても並びが一定になるようにする。
        let ordered = HobbyCard.catalog.map(\.id).filter { selected.contains($0) }
        let success = await profileManager.saveHobbyCards(ordered)
        isSaving = false
        if success {
            dismiss()
        } else {
            showingFailedAlert = true
        }
    }
}

#Preview {
    HobbyCardPickerView(profileManager: .preview)
}

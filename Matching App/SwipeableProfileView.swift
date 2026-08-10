//
//  SwipeableProfileView.swift
//  Matching App
//

import SwiftUI

/// 複数のプロフィールを左右スワイプで切り替えながら閲覧できるコンテナ。
struct SwipeableProfileView<ActionContent: View>: View {
    let profiles: [Profile]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var actionContent: (Profile, @escaping () -> Void) -> ActionContent

    init(profiles: [Profile], startIndex: Int, @ViewBuilder actionContent: @escaping (Profile, @escaping () -> Void) -> ActionContent) {
        self.profiles = profiles
        self._currentIndex = State(initialValue: startIndex)
        self.actionContent = actionContent
    }

    /// 互換用: 「次の人へ進む」機能を使わない呼び出し元向けの初期化。
    init(profiles: [Profile], startIndex: Int, @ViewBuilder actionContent: @escaping (Profile) -> ActionContent) {
        self.init(profiles: profiles, startIndex: startIndex) { profile, _ in
            actionContent(profile)
        }
    }

    private var currentProfile: Profile? {
        guard profiles.indices.contains(currentIndex) else { return nil }
        return profiles[currentIndex]
    }

    /// 非表示等でその場を離れる時、次のプロフィールがあれば進み、なければ一覧に戻る。
    private func advanceOrDismiss() {
        if currentIndex + 1 < profiles.count {
            withAnimation { currentIndex += 1 }
        } else {
            dismiss()
        }
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                OtherUserProfileView(profile: profile) {
                    actionContent(profile, advanceOrDismiss)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(currentProfile?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

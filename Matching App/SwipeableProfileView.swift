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
    @State private var showingHideConfirm = false
    @State private var showingBlockConfirm = false
    @State private var showingReportSheet = false
    @State private var toastMessage: String?
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
                // TabViewは表示していないページのビューも同時に生かしているため、
                // 各ページが自前でツールバーを持つと「…」ボタンがページ数分だけ並んでしまう。
                // メニューはここで現在のページの分だけ1つ出す。
                OtherUserProfileView(profile: profile, showsModerationMenu: false) {
                    actionContent(profile, advanceOrDismiss)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(currentProfile?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileModerationMenu(
                    onHide: { showingHideConfirm = true },
                    onBlock: { showingBlockConfirm = true },
                    onReport: { showingReportSheet = true }
                )
            }
        }
        .confirmationDialog(
            "\(currentProfile?.name ?? "この人")さんを非表示にしますか?",
            isPresented: $showingHideConfirm,
            titleVisibility: .visible
        ) {
            Button("非表示にする", role: .destructive) {
                guard let target = currentProfile else { return }
                Task {
                    let succeeded = await UserModeration.hide(userId: target.id)
                    // 下部の非表示ボタンと同じく、自動では次へ進まずスワイプ操作に任せる。
                    toastMessage = succeeded ? "非表示にしました" : "非表示にできませんでした"
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今後「探す」画面に表示されなくなります")
        }
        .confirmationDialog(
            "\(currentProfile?.name ?? "この人")さんをブロックしますか?",
            isPresented: $showingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("ブロックする", role: .destructive) {
                guard let target = currentProfile else { return }
                Task {
                    let succeeded = await UserModeration.block(userId: target.id)
                    if succeeded {
                        advanceOrDismiss()
                    } else {
                        toastMessage = "ブロックできませんでした"
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showingReportSheet) {
            if let target = currentProfile {
                ReportReasonSheet(targetName: target.name) { reason in
                    Task {
                        let succeeded = await UserModeration.report(userId: target.id, reason: reason)
                        toastMessage = succeeded ? "報告しました" : "報告できませんでした"
                    }
                }
            }
        }
        .actionToast($toastMessage)
    }
}

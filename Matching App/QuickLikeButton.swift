//
//  QuickLikeButton.swift
//  Matching App
//

import SwiftUI
import Supabase

/// 特定のManagerに依存せず、単体でいいねを送信できる汎用ボタン。
/// プロフィール下部の「他のユーザー」おすすめ一覧などから遷移した先で使う。
struct QuickLikeButton: View {
    let profile: Profile
    let photoURL: URL?
    /// スワイプで複数人を見ている場合に、送信後「次のお相手へ」進めるためのコールバック。
    var onSent: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var alreadyLiked = false
    /// 既にいいね済みかの確認(loadStatus)が終わるまでは送信させない。
    /// ここを待たずに連打できると、実際は送信済みなのに`alreadyLiked`がまだfalseのまま
    /// 二重送信してしまい、DBのunique制約違反が原因不明の「いいねが足りません」表示に
    /// 化けてしまっていた。
    @State private var hasLoadedStatus = false
    @State private var showingPopularSheet = false
    @State private var showingSentConfirmation = false
    @State private var showingInsufficientLikesAlert = false

    init(profile: Profile, photoURL: URL? = nil, onSent: (() -> Void)? = nil) {
        self.profile = profile
        self.photoURL = photoURL
        self.onSent = onSent
    }

    var body: some View {
        Button {
            guard hasLoadedStatus, !isSending, !alreadyLiked else { return }
            isSending = true
            Task {
                let count = (try? await supabase()
                    .rpc("get_like_count", params: ["target_user_id": profile.id])
                    .execute()
                    .value) as Int? ?? 0
                isSending = false
                if count >= DiscoverManager.popularMemberThreshold {
                    showingPopularSheet = true
                } else {
                    await sendAndConfirm(isSpecial: false)
                }
            }
        } label: {
            HStack {
                Image(systemName: alreadyLiked ? "checkmark" : "hand.thumbsup.fill")
                Text(alreadyLiked ? "いいね送信済み" : "いいねを送る")
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(alreadyLiked ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Color.brandPurple))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(!hasLoadedStatus || isSending || alreadyLiked)
        .task {
            await loadStatus()
        }
        .sheet(isPresented: $showingPopularSheet) {
            PopularMemberSheet(profile: profile, photoURL: photoURL) { useSpecial in
                showingPopularSheet = false
                Task { await sendAndConfirm(isSpecial: useSpecial) }
            }
        }
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: "いいねを送りました", icon: "hand.thumbsup.fill")
        .alert("いいねを送れませんでした", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("残いいねが足りないか、通信に失敗した可能性があります。マイページからいいねを増やしてから、もう一度お試しください。")
        }
    }

    private func loadStatus() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            let existing: [Like] = try await supabase()
                .from("likes")
                .select()
                .eq("from_user_id", value: myId)
                .eq("to_user_id", value: profile.id)
                .execute()
                .value
            alreadyLiked = !existing.isEmpty
        } catch {
            print("quick like status error: \(error)")
        }
        hasLoadedStatus = true
    }

    private func sendAndConfirm(isSpecial: Bool) async {
        isSending = true
        let success = await sendLike(isSpecial: isSpecial)
        isSending = false
        guard success else {
            showingInsufficientLikesAlert = true
            return
        }
        alreadyLiked = true
        showingSentConfirmation = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        showingSentConfirmation = false
        // 送ったお相手をもう一度見せても操作できることがないため、そのまま次のお相手へ送る。
        if let onSent {
            onSent()
        } else {
            dismiss()
        }
    }

    private func sendLike(isSpecial: Bool) async -> Bool {
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: profile.id, pIsSpecial: isSpecial))
                .execute()
            await PushNotifier.notify(userId: profile.id, title: String.appLocalized("いいねが届きました!"), body: String.appLocalized("誰かがあなたのプロフィールにいいねしました"), type: .like)
            return true
        } catch {
            print("quick like send error: \(error)")
            return false
        }
    }
}

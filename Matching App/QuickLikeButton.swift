//
//  QuickLikeButton.swift
//  Matching App
//

import SwiftUI
import Supabase

/// 特定のManagerに依存せず、単体でいいね/見てねを送信できる汎用ボタン。
/// プロフィール下部の「他のユーザー」おすすめ一覧などから遷移した先で使う。
struct QuickLikeButton: View {
    let profile: Profile
    let photoURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var alreadyLiked = false
    @State private var alreadyReminded = false
    @State private var showingPopularSheet = false
    @State private var showingSentConfirmation = false
    @State private var confirmationMessage = "いいねを送りました"
    @State private var confirmationIcon = "hand.thumbsup.fill"
    @State private var showingInsufficientLikesAlert = false

    init(profile: Profile, photoURL: URL? = nil) {
        self.profile = profile
        self.photoURL = photoURL
    }

    var body: some View {
        Button {
            Task {
                if alreadyLiked {
                    await sendReminderAndConfirm()
                    return
                }
                isSending = true
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
                Image(systemName: alreadyReminded ? "checkmark" : (alreadyLiked ? "bell.fill" : "hand.thumbsup.fill"))
                Text(alreadyReminded ? "見てね送信済み" : (alreadyLiked ? "見てね" : "いいねを送る"))
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(alreadyReminded ? Color.gray : (alreadyLiked ? Color.purple : Color.brandBlue))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(isSending || alreadyReminded)
        .task {
            await loadStatus()
        }
        .sheet(isPresented: $showingPopularSheet) {
            PopularMemberSheet(profile: profile, photoURL: photoURL) { useSpecial in
                showingPopularSheet = false
                Task { await sendAndConfirm(isSpecial: useSpecial) }
            }
        }
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: confirmationMessage, icon: confirmationIcon)
        .alert("いいねが足りません", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("マイページからいいねを増やしてください。")
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
            if let like = existing.first {
                alreadyLiked = true
                alreadyReminded = like.isReminded && !like.canSendReminder
            }
        } catch {
            print("quick like status error: \(error)")
        }
    }

    private func sendAndConfirm(isSpecial: Bool) async {
        isSending = true
        let success = await sendLike(isSpecial: isSpecial)
        isSending = false
        guard success else {
            showingInsufficientLikesAlert = true
            return
        }
        confirmationMessage = "いいねを送りました"
        confirmationIcon = "hand.thumbsup.fill"
        showingSentConfirmation = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        showingSentConfirmation = false
        dismiss()
    }

    private func sendReminderAndConfirm() async {
        isSending = true
        let success = await sendReminder()
        isSending = false
        guard success else {
            showingInsufficientLikesAlert = true
            return
        }
        confirmationMessage = "\(DiscoverManager.reminderLikeCost)いいね使いました"
        confirmationIcon = "bell.fill"
        showingSentConfirmation = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        showingSentConfirmation = false
        dismiss()
    }

    private func sendLike(isSpecial: Bool) async -> Bool {
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: profile.id, pIsSpecial: isSpecial))
                .execute()
            return true
        } catch {
            print("quick like send error: \(error)")
            return false
        }
    }

    private func sendReminder() async -> Bool {
        do {
            try await supabase()
                .rpc("send_reminder_atomic", params: ["p_to_user_id": profile.id])
                .execute()
            return true
        } catch {
            print("quick reminder send error: \(error)")
            return false
        }
    }
}

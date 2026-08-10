//
//  ChatListView.swift
//  Matching App
//

import SwiftUI
import Supabase

struct ChatListView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var pendingHideMatch: MatchedChat?
    @State private var pendingBlockMatch: MatchedChat?
    @State private var showsStaleNudge = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsStaleNudge, !chatManager.staleMatches.isEmpty {
                    staleNudgeBanner
                }
                sortChips

                if chatManager.matches.isEmpty && !chatManager.isLoading {
                    ScrollView {
                        Text("まだマッチしたお相手がいません")
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        await chatManager.load()
                    }
                } else {
                    List(chatManager.matches) { match in
                        NavigationLink {
                            ChatView(matchId: match.match.id, otherProfile: match.profile, otherPhotoURL: match.photoURL)
                        } label: {
                            HStack(spacing: 12) {
                                IconImage(url: match.photoURL, size: 54)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(match.profile.name)
                                            .font(.subheadline.bold())
                                        Text(match.profile.ageLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(previewText(for: match))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    if let date = match.lastMessage?.createdAt {
                                        Text(relativeTime(date))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if match.unreadCount > 0 {
                                        Text("\(match.unreadCount)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(Color.brandRed, in: Circle())
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingBlockMatch = match
                            } label: {
                                Label("ブロック", systemImage: "hand.raised.fill")
                            }
                            Button {
                                pendingHideMatch = match
                            } label: {
                                Label("非表示", systemImage: "eye.slash")
                            }
                            .tint(.gray)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await chatManager.load()
                    }
                }
            }
            .background(Color.appListBackground.ignoresSafeArea())
            .navigationTitle("トーク")
            .task {
                await chatManager.load()
            }
            .confirmationDialog(
                "このトークを非表示にしますか?",
                isPresented: Binding(get: { pendingHideMatch != nil }, set: { if !$0 { pendingHideMatch = nil } }),
                titleVisibility: .visible
            ) {
                Button("非表示にする", role: .destructive) {
                    if let match = pendingHideMatch {
                        Task {
                            await hideChat(matchId: match.match.id)
                            await chatManager.load()
                        }
                    }
                    pendingHideMatch = nil
                }
                Button("キャンセル", role: .cancel) { pendingHideMatch = nil }
            }
            .confirmationDialog(
                "\(pendingBlockMatch?.profile.name ?? "")さんをブロックしますか?",
                isPresented: Binding(get: { pendingBlockMatch != nil }, set: { if !$0 { pendingBlockMatch = nil } }),
                titleVisibility: .visible
            ) {
                Button("ブロックする", role: .destructive) {
                    if let match = pendingBlockMatch {
                        Task {
                            await UserModeration.block(userId: match.profile.id)
                            await chatManager.load()
                        }
                    }
                    pendingBlockMatch = nil
                }
                Button("キャンセル", role: .cancel) { pendingBlockMatch = nil }
            } message: {
                Text("ブロックするとお互いにメッセージが送れなくなります")
            }
        }
    }

    private func hideChat(matchId: UUID) async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        struct Payload: Encodable {
            let userId: UUID
            let matchId: UUID
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case matchId = "match_id"
            }
        }
        do {
            try await supabase()
                .from("hidden_matches")
                .upsert(Payload(userId: myId, matchId: matchId), onConflict: "user_id,match_id")
                .execute()
        } catch {
            print("hide chat error: \(error)")
        }
    }

    private var staleNudgeBanner: some View {
        let stale = chatManager.staleMatches
        return NavigationLink {
            if let first = stale.first {
                ChatView(matchId: first.match.id, otherProfile: first.profile, otherPhotoURL: first.photoURL)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                    .foregroundStyle(Color.brandOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stale.count == 1 ? "\(stale[0].profile.name)さんとの会話が止まっています" : "\(stale.count)件のトークが止まっています")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("話しかけてみましょう!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { showsStaleNudge = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.brandOrange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    private var sortChips: some View {
        HStack(spacing: 8) {
            sortChip(title: "すべて", isSelected: chatManager.sortMode == .recent) {
                chatManager.sortMode = .recent
            }
            sortChip(title: "未返信", isSelected: chatManager.sortMode == .unreplied) {
                chatManager.sortMode = .unreplied
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func sortChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brandRed : Color(.systemGray6), in: Capsule())
        }
    }

    private func previewText(for match: MatchedChat) -> String {
        guard let lastMessage = match.lastMessage else { return "マッチ済み" }
        if let body = lastMessage.body, !body.isEmpty { return body }
        if lastMessage.imageUrl != nil { return "[画像]" }
        return "マッチ済み"
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ChatListView()
}

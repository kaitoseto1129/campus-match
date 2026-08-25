//
//  GatheringChatView.swift
//  Matching App
//

import SwiftUI
import Supabase

struct GatheringChatView: View {
    let gathering: Gathering
    @StateObject private var chatManager: GatheringChatManager
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var draftText = ""
    @State private var draftFieldResetToken = UUID()
    @State private var membersById: [UUID: Profile] = [:]
    @State private var photoURLsById: [UUID: URL] = [:]
    /// 表示順を安定させるため、辞書とは別に主催者を先頭にしたID順を保持する。
    @State private var orderedMemberIds: [UUID] = []

    private var myId: UUID? { supabase().auth.currentUser?.id }

    init(gathering: Gathering) {
        self.gathering = gathering
        _chatManager = StateObject(wrappedValue: GatheringChatManager(gatheringId: gathering.id))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if chatManager.messages.isEmpty && !chatManager.isLoading {
                        Text("最初のメッセージを送って挨拶してみましょう")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(chatManager.messages) { message in
                        GatheringMessageBubbleView(
                            message: message,
                            isMine: message.senderId == myId,
                            senderName: membersById[message.senderId]?.name.displayNameForCurrentLanguage,
                            senderPhotoURL: photoURLsById[message.senderId]
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.brandPurple.opacity(0.08), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onChange(of: chatManager.messages.last?.id) { _, newLastId in
                guard let newLastId else { return }
                withAnimation { proxy.scrollTo(newLastId, anchor: .bottom) }
            }
            .onAppear {
                guard let lastId = chatManager.messages.last?.id else { return }
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
        .navigationTitle(gathering.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            memberHeader
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
        }
        .task {
            await chatManager.load()
            await chatManager.subscribe()
            await loadMembers()
        }
        .onAppear { tabRouter.pushDetailScreen() }
        .onDisappear {
            tabRouter.popDetailScreen()
            Task { await chatManager.unsubscribe() }
        }
    }

    private func loadMembers() async {
        do {
            let applications: [GatheringApplication] = try await supabase()
                .from("gathering_applications")
                .select("*")
                .eq("gathering_id", value: gathering.id)
                .eq("status", value: "accepted")
                .execute()
                .value
            let otherMemberIds = applications.map(\.applicantId).filter { $0 != gathering.hostId }
            let memberIds = [gathering.hostId] + otherMemberIds
            let profiles: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: memberIds)
                .execute()
                .value
            membersById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            photoURLsById = await loadMainPhotoURLs(userIds: memberIds)
            orderedMemberIds = memberIds
        } catch {
            print("gathering members load error: \(error)")
        }
    }

    /// トーク画面を開いた時、誰が参加予定なのかひと目で分かるように上部に出すヘッダー。
    private var memberHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Label {
                    Text(gathering.scheduledAt, format: .dateTime.month().day().hour().minute())
                } icon: {
                    Image(systemName: "clock")
                }
                Label {
                    Text(gathering.location).lineLimit(1)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(orderedMemberIds, id: \.self) { id in
                        VStack(spacing: 4) {
                            IconImage(url: photoURLsById[id], size: 40)
                            Text(membersById[id]?.name.displayNameForCurrentLanguage ?? "-")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 56)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("メッセージを入力", text: $draftText, axis: .vertical)
                .id(draftFieldResetToken)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Button {
                let text = draftText
                draftText = ""
                draftFieldResetToken = UUID()
                Task {
                    let succeeded = await chatManager.send(text: text)
                    if succeeded {
                        await notifyOtherMembers()
                    } else if draftText.isEmpty {
                        draftText = text
                    }
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.brandPurple)
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isSending)
            .accessibilityLabel("送信")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// メッセージを送った直後、自分以外のメンバー全員にプッシュ通知で気付いてもらう。
    private func notifyOtherMembers() async {
        guard let myId else { return }
        let myName = membersById[myId]?.name.displayNameForCurrentLanguage
        let title = myName.map { String.appLocalized("%@さんからメッセージが届きました", $0) } ?? String.appLocalized("メッセージが届きました")
        for memberId in membersById.keys where memberId != myId {
            await PushNotifier.notify(userId: memberId, title: title, body: gathering.title, type: .gathering)
        }
    }
}

private struct GatheringMessageBubbleView: View {
    let message: GatheringMessage
    let isMine: Bool
    let senderName: String?
    let senderPhotoURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMine {
                Spacer(minLength: 40)
            } else {
                IconImage(url: senderPhotoURL, size: 28)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine, let senderName {
                    Text(senderName)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                Text(message.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? Color.brandPurple : Color(.systemGray6))
                    .foregroundStyle(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}

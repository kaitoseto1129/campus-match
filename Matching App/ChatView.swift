//
//  ChatView.swift
//  Matching App
//

import SwiftUI
import PhotosUI
import Supabase

struct ChatView: View {
    let otherProfile: Profile
    let otherPhotoURL: URL?
    @StateObject private var messageManager: MessageManager
    @EnvironmentObject private var notificationManager: NotificationCenterManager
    @EnvironmentObject private var tabRouter: TabRouter
    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String = ""
    @State private var draftFieldResetToken = UUID()
    @State private var pickerItem: PhotosPickerItem?
    @State private var fullScreenImageURL: URL?
    @State private var showingProfile = false
    @State private var showingHideConfirm = false
    @State private var showingBlockConfirm = false
    @State private var showingReportConfirm = false
    @State private var showingCallRequestConfirm = false
    @State private var showingCancelCallRequestConfirm = false
    @State private var showingCallAcceptedAlert = false
    @State private var showingCallDeclinedAlert = false
    @State private var isBlocked = false

    private var myId: UUID? { supabase().auth.currentUser?.id }

    init(matchId: UUID, otherProfile: Profile, otherPhotoURL: URL? = nil) {
        self.otherProfile = otherProfile
        self.otherPhotoURL = otherPhotoURL
        _messageManager = StateObject(wrappedValue: MessageManager(matchId: matchId))
    }

    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if messageManager.hasMoreOlderMessages {
                        Button {
                            Task { await messageManager.loadOlderMessages() }
                        } label: {
                            if messageManager.isLoadingOlder {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("過去のメッセージを読み込む")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(messageManager.isLoadingOlder)
                        .padding(.vertical, 8)
                    }
                    ForEach(messageManager.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isMine: message.senderId == myId,
                            showsReadReceipt: showsReadReceipt(for: message),
                            onTapImage: {
                                if let url = message.imageUrl {
                                    fullScreenImageURL = url
                                }
                            },
                            onUnsend: {
                                Task { await messageManager.unsend(message) }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messageManager.messages.last?.id) { _, newLastId in
                // 末尾のIDが変わった時(=新着メッセージ)だけ自動スクロールする。
                // 過去メッセージの先頭への追加(loadOlderMessages)では末尾は変わらないため発火しない。
                guard let newLastId else { return }
                withAnimation {
                    proxy.scrollTo(newLastId, anchor: .bottom)
                }
            }
            .onAppear {
                guard let lastId = messageManager.messages.last?.id else { return }
                proxy.scrollTo(lastId, anchor: .bottom)
            }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        if value.translation.width > 60 && abs(value.translation.height) < 50 {
                            showingProfile = true
                        }
                    }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
    }

    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showingProfile = true
            } label: {
                HStack(spacing: 8) {
                    IconImage(url: otherPhotoURL, size: 32)
                    HStack(spacing: 4) {
                        Text(otherProfile.name)
                            .font(.subheadline.bold())
                        Text(otherProfile.ageLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if messageManager.outgoingCallRequestStatus == .pending {
                    showingCancelCallRequestConfirm = true
                } else {
                    showingCallRequestConfirm = true
                }
            } label: {
                Image(systemName: messageManager.outgoingCallRequestStatus == .pending ? "phone.badge.waveform" : "phone")
                    .foregroundStyle(messageManager.outgoingCallRequestStatus == .pending ? Color.brandOrange : Color.accentColor)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingHideConfirm = true
                } label: {
                    Label("非表示にする", systemImage: "eye.slash")
                }
                Button(role: .destructive) {
                    showingBlockConfirm = true
                } label: {
                    Label("ブロックする", systemImage: "hand.raised.fill")
                }
                Button(role: .destructive) {
                    showingReportConfirm = true
                } label: {
                    Label("違反報告する", systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    @ViewBuilder
    private func callRequestUI<Content: View>(_ content: Content) -> some View {
        content
            .confirmationDialog("\(otherProfile.name)さんに通話をリクエストしますか?", isPresented: $showingCallRequestConfirm, titleVisibility: .visible) {
                Button("リクエストする") {
                    Task { await messageManager.requestCall() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("いきなり発信はされません。相手が承諾した場合のみ通話に進めます。")
            }
            .confirmationDialog("通話リクエストを取り消しますか?", isPresented: $showingCancelCallRequestConfirm, titleVisibility: .visible) {
                Button("取り消す", role: .destructive) {
                    Task { await messageManager.cancelCallRequest() }
                }
                Button("戻る", role: .cancel) {}
            }
            .alert("\(otherProfile.name)さんが通話を許可しました", isPresented: $showingCallAcceptedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("この先の通話機能は準備中です。")
            }
            .alert("今は難しいようです", isPresented: $showingCallDeclinedAlert) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: messageManager.outgoingCallRequestStatus) { _, newValue in
                switch newValue {
                case .accepted:
                    showingCallAcceptedAlert = true
                    messageManager.outgoingCallRequestStatus = nil
                case .declined, .canceled:
                    if newValue == .declined { showingCallDeclinedAlert = true }
                    messageManager.outgoingCallRequestStatus = nil
                case .pending, nil:
                    break
                }
            }
            .alert(
                "\(otherProfile.name)さんが通話をリクエストしています",
                isPresented: Binding(
                    get: { messageManager.incomingCallRequest != nil },
                    set: { if !$0 { messageManager.incomingCallRequest = nil } }
                )
            ) {
                Button("許可する") {
                    Task { await messageManager.respondToCallRequest(accept: true) }
                }
                Button("今は無理", role: .cancel) {
                    Task { await messageManager.respondToCallRequest(accept: false) }
                }
            } message: {
                Text("許可すると相手に伝わります。この先の通話機能は準備中です。")
            }
    }

    var body: some View {
        callRequestUI(chatContent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { chatToolbar }
        .confirmationDialog("このトークを非表示にしますか?", isPresented: $showingHideConfirm, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                Task {
                    await hideChat()
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("\(otherProfile.name)さんをブロックしますか?", isPresented: $showingBlockConfirm, titleVisibility: .visible) {
            Button("ブロックする", role: .destructive) {
                Task {
                    await UserModeration.block(userId: otherProfile.id)
                    isBlocked = true
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ブロックするとお互いにメッセージが送れなくなります")
        }
        .confirmationDialog("違反報告しますか?", isPresented: $showingReportConfirm, titleVisibility: .visible) {
            Button("報告する", role: .destructive) {
                Task { await UserModeration.report(userId: otherProfile.id, reason: "チャットからの報告") }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showingProfile) {
            OtherUserProfileView(profile: otherProfile) { EmptyView() }
        }
        .task {
            await messageManager.load()
            await messageManager.subscribe()
            await notificationManager.refresh()
            if let myId {
                isBlocked = await UserModeration.isBlocked(between: myId, and: otherProfile.id)
            }
        }
        .onAppear {
            tabRouter.pushDetailScreen()
        }
        .onDisappear {
            tabRouter.popDetailScreen()
            Task { await messageManager.unsubscribe() }
        }
        .onChange(of: draftText) { _, newValue in
            Task { await messageManager.sendTypingStatus(isTyping: !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .onChange(of: pickerItem) { _, newValue in
            Task {
                guard let newValue,
                      let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await messageManager.sendImage(image)
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullScreenImageURL != nil },
            set: { if !$0 { fullScreenImageURL = nil } }
        )) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                AsyncImage(url: fullScreenImageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    }
                }
                Button {
                    fullScreenImageURL = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding()
                }
            }
        }
    }

    private func hideChat() async {
        guard let myId else { return }
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
                .upsert(Payload(userId: myId, matchId: messageManager.matchId), onConflict: "user_id,match_id")
                .execute()
        } catch {
            print("hide chat error: \(error)")
        }
    }

    private func showsReadReceipt(for message: Message) -> Bool {
        guard let myId, message.senderId == myId, message.isRead else { return false }
        return message.id == messageManager.messages.last?.id
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if messageManager.isOtherUserTyping {
                typingIndicatorRow
            }
            Divider()
            if isBlocked {
                Text("ブロックしているため、メッセージを送信できません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                inputBar
            }
        }
        .background(.bar)
    }

    private var typingIndicatorRow: some View {
        HStack(spacing: 6) {
            TypingDotsView()
            Text("\(otherProfile.name)さんが入力中...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .transition(.opacity)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Color.brandRed)
            }

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
                Task { await messageManager.send(text: text) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.brandRed)
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messageManager.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

private struct MessageBubbleView: View {
    let message: Message
    let isMine: Bool
    let showsReadReceipt: Bool
    let onTapImage: () -> Void
    let onUnsend: () -> Void
    @State private var showingUnsendConfirm = false

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if message.isDeleted {
                    Text("送信を取り消しました")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
                } else {
                    if let imageUrl = message.imageUrl {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color(.systemGray6)
                            }
                        }
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture { onTapImage() }
                    }
                    if let body = message.body, !body.isEmpty {
                        Text(body)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isMine ? Color.brandRed : Color(.systemGray6))
                            .foregroundStyle(isMine ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .contextMenu {
                                if isMine {
                                    Button(role: .destructive) {
                                        showingUnsendConfirm = true
                                    } label: {
                                        Label("送信を取り消す", systemImage: "arrow.uturn.backward")
                                    }
                                }
                            }
                    }
                    if showsReadReceipt {
                        Text("既読")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
        .confirmationDialog("送信を取り消しますか?", isPresented: $showingUnsendConfirm, titleVisibility: .visible) {
            Button("取り消す", role: .destructive) { onUnsend() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("相手の画面からもメッセージが消えます")
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(matchId: UUID(), otherProfile: ProfileManager.preview.profile!)
    }
    .environmentObject(NotificationCenterManager())
    .environmentObject(TabRouter())
}

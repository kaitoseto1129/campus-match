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
    @State private var showingReportSheet = false
    @State private var showingCallRequestConfirm = false
    @State private var showingCancelCallRequestConfirm = false
    @State private var isBlocked = false
    @State private var showingBlockFailedAlert = false
    @State private var toastMessage: String?
    /// 自分の会員ステータス。無料会員は1日にメッセージできる人数に上限があり、既読はVIPのみ見える。
    @State private var myMembership: MembershipTier = .free
    /// 無料会員の場合、今日この相手に新しくメッセージを送れるか(既に今日やり取りした相手か、まだ上限に達していなければtrue)。
    @State private var canMessageToday = true
    @State private var showingMembership = false
    @State private var showingImagePickFailedAlert = false
    /// 最初のメッセージ促進バナー・自動生成に使う自分のプロフィール(趣味カードの共通点抽出のため)。
    @State private var myProfile: Profile? = nil
    @State private var myPhotoURL: URL? = nil
    @State private var showingMessageComposer = false

    private var myId: UUID? { supabase().auth.currentUser?.id }

    /// お互いが選んでいる共通の趣味カード。話題のきっかけとして提示する。
    private var sharedHobbyCards: [HobbyCard] {
        guard let myProfile else { return [] }
        let shared = Set(myProfile.hobbyCards).intersection(otherProfile.hobbyCards)
        return HobbyCard.cards(for: Array(shared))
    }

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
                    if messageManager.messages.isEmpty && !messageManager.isLoading {
                        firstMessageNudge
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
                    callRequestBubbles
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
        // 以前はtopBarLeadingに置いていたが、戻るボタン・右側のアイコン2つ(通話・メニュー)と
        // 幅を取り合って、実機では名前・年齢のテキストだけ見えなくなることがあった。
        // .principal(タイトル中央)は元々このための領域で幅にも余裕があるため、そちらに置く
        // (LINEやメッセージアプリのトーク画面ヘッダーと同じ配置)。
        ToolbarItem(placement: .principal) {
            Button {
                showingProfile = true
            } label: {
                HStack(spacing: 8) {
                    IconImage(url: otherPhotoURL, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(otherProfile.name.displayNameForCurrentLanguage)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(otherProfile.ageLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
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
                    showingReportSheet = true
                } label: {
                    Label("違反報告する", systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("その他の操作")
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
                Text("「電話をします」というメッセージが相手に届きます。相手がタップして許可した場合のみ通話に進めます。")
            }
            .confirmationDialog("通話リクエストを取り消しますか?", isPresented: $showingCancelCallRequestConfirm, titleVisibility: .visible) {
                Button("取り消す", role: .destructive) {
                    Task { await messageManager.cancelCallRequest() }
                }
                Button("戻る", role: .cancel) {}
            }
    }

    /// マッチ直後、まだ誰もメッセージを送っていない時に表示する促進バナー。
    /// 以前はメッセージが0件だと画面が真っ白で何をすればいいか分からなかったため、
    /// お互いの写真・共通の趣味・最初のメッセージ自動生成への導線をまとめて出す。
    /// 最初のメッセージが送られると(messageManager.messages.isEmpty が false になると)自動的に消える。
    private var firstMessageNudge: some View {
        VStack(spacing: 16) {
            HStack(spacing: -14) {
                IconImage(url: myPhotoURL, size: 56)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                IconImage(url: otherPhotoURL, size: 56)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }

            Text("マッチしました!最初のメッセージを送ってみましょう")
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)

            if !sharedHobbyCards.isEmpty {
                VStack(spacing: 8) {
                    Text("話題になりそうな共通点")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    FlowLayoutView(options: sharedHobbyCards.map { "\($0.emoji) \(String.appLocalized($0.title))" }) { label in
                        Text(label)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandPurple.opacity(0.1), in: Capsule())
                            .foregroundStyle(Color.brandPurple)
                    }
                }
            }

            Button {
                showingMessageComposer = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("最初のメッセージを自動生成")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.brandGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }

            Text("※ 安全のため、1通目でのご連絡先の交換はお控えください。直接会ってから交換することをおすすめします")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .padding(.bottom, 8)
        .sheet(isPresented: $showingMessageComposer) {
            FirstMessageComposerSheet(otherName: otherProfile.name, sharedHobbyCards: sharedHobbyCards) { text in
                showingMessageComposer = false
                Task {
                    await messageManager.send(text: text)
                    await notifyOtherOfNewMessage()
                }
            } onCustomize: { text in
                showingMessageComposer = false
                draftText = text
            }
        }
    }

    /// 通話リクエストを、システムアラートではなくメッセージ風のバブルとしてトーク欄に表示する。
    /// 相手からのリクエストはこのバブルをタップして応答する。
    @ViewBuilder
    private var callRequestBubbles: some View {
        if let incoming = messageManager.incomingCallRequest, incoming.status == .pending {
            CallRequestBubbleView(isMine: false, name: otherProfile.name, status: .pending) {
                Task { await messageManager.respondToCallRequest(accept: true) }
            } onDecline: {
                Task { await messageManager.respondToCallRequest(accept: false) }
            }
        }
        if let status = messageManager.outgoingCallRequestStatus {
            CallRequestBubbleView(isMine: true, name: otherProfile.name, status: status, onAccept: nil, onDecline: nil)
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
                    let succeeded = await UserModeration.block(userId: otherProfile.id)
                    if succeeded {
                        // ブロックしたトークは一覧にも表示され続けるべきではないため、その場で閉じる。
                        dismiss()
                    } else {
                        // 失敗したのに閉じてしまうと、実際は相手をブロックできていないのに
                        // 「ブロックできた」と誤解したままトークだけ消える(相手からは
                        // 引き続き連絡できてしまう)ため、成功した場合のみ閉じる。
                        showingBlockFailedAlert = true
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ブロックするとお互いにメッセージが送れなくなり、このトークは一覧から消えます")
        }
        .alert("ブロックできませんでした", isPresented: $showingBlockFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("通信環境をご確認のうえ、もう一度お試しください。")
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportReasonSheet(targetName: otherProfile.name) { reason in
                Task {
                    let succeeded = await UserModeration.report(userId: otherProfile.id, reason: reason)
                    toastMessage = succeeded ? "報告しました" : "報告できませんでした"
                }
            }
        }
        .actionToast($toastMessage)
        .alert("送信できません", isPresented: Binding(
            get: { messageManager.errorMessage != nil },
            set: { if !$0 { messageManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(messageManager.errorMessage ?? ""))
        }
        .navigationDestination(isPresented: $showingProfile) {
            OtherUserProfileView(profile: otherProfile) {
                Button {
                    showingProfile = false
                } label: {
                    Text("トークに戻る")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.brandPurple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationDestination(isPresented: $showingMembership) {
            MembershipStatusView(profileManager: ProfileManager())
        }
        .task {
            await messageManager.load()
            // load()の完了を待つ間に画面を閉じていた場合、.taskはキャンセルされるが
            // onDisappear側のunsubscribe()は既にchannelがnilの状態で空振りしてしまっている
            // ことがある。ここでキャンセル済みならsubscribe()自体を呼ばないようにして、
            // 誰にも解除されない購読済みチャンネルが残ってしまうのを防ぐ。
            guard !Task.isCancelled else { return }
            await messageManager.subscribe()
            await notificationManager.refresh()
            if let myId {
                isBlocked = await UserModeration.isBlocked(between: myId, and: otherProfile.id)
                myMembership = await MembershipLookup.myTier()
                await refreshDailyMessageLimit(myId: myId)
                await loadMyProfileForNudge(myId: myId)
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
                guard let newValue else { return }
                defer { pickerItem = nil }
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        showingImagePickFailedAlert = true
                        return
                    }
                    await messageManager.sendImage(image)
                    await notifyOtherOfNewMessage()
                } catch {
                    showingImagePickFailedAlert = true
                    print("chat image load error: \(error)")
                }
            }
        }
        .alert("画像を読み込めませんでした", isPresented: $showingImagePickFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("もう一度お試しください。")
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

    /// 最初のメッセージ促進バナー用に、共通の趣味カード抽出に必要な自分のプロフィールと写真を読み込む。
    private func loadMyProfileForNudge(myId: UUID) async {
        do {
            myProfile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value
            let photos: [ProfilePhoto] = try await supabase()
                .from("profile_photos")
                .select("*")
                .eq("user_id", value: myId)
                .eq("order_number", value: 0)
                .execute()
                .value
            myPhotoURL = photos.first?.url
        } catch {
            print("load my profile for nudge error: \(error)")
        }
    }

    /// メッセージを送った直後、相手にプッシュ通知で気付いてもらう。
    /// 送信自体が失敗していても通知だけ送ってしまう可能性はあるが、失敗はまれで実害も小さいため、
    /// ここでは送信結果を厳密に判定せず割り切っている。
    private func notifyOtherOfNewMessage() async {
        let title = myProfile.map { String.appLocalized("%@さんからメッセージが届きました", $0.name.displayNameForCurrentLanguage) } ?? String.appLocalized("メッセージが届きました")
        await PushNotifier.notify(userId: otherProfile.id, title: title, body: String.appLocalized("トークを確認してみましょう"))
    }

    /// 既読表示はVIPオプション限定の機能。通常会員のトークでは既読は分からない。
    private func showsReadReceipt(for message: Message) -> Bool {
        guard myMembership.canSeeReadReceipts else { return false }
        guard let myId, message.senderId == myId, message.isRead else { return false }
        return message.id == messageManager.messages.last?.id
    }

    private struct MatchIdRow: Decodable {
        let matchId: UUID
        enum CodingKeys: String, CodingKey { case matchId = "match_id" }
    }

    /// 無料会員は1日に新しくメッセージできる相手が限られる。既にやり取りした相手ならこれまで通り送れる。
    private func refreshDailyMessageLimit(myId: UUID) async {
        guard myMembership.hasDailyMessagePartnerLimit else {
            canMessageToday = true
            return
        }
        do {
            let startOfDay = ISO8601DateFormatter.matchingApp.string(from: Calendar.current.startOfDay(for: Date()))
            let rows: [MatchIdRow] = try await supabase()
                .from("messages")
                .select("match_id")
                .eq("sender_id", value: myId)
                .gte("created_at", value: startOfDay)
                .execute()
                .value
            let partnerMatchIds = Set(rows.map(\.matchId))
            canMessageToday = partnerMatchIds.contains(messageManager.matchId)
                || partnerMatchIds.count < MembershipTier.freeDailyMessagePartnerLimit
        } catch {
            print("daily message limit check error: \(error)")
            canMessageToday = true
        }
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
            } else if !canMessageToday {
                dailyLimitPrompt
            } else {
                inputBar
            }
        }
        .background(.bar)
    }

    /// 無料会員が1日の新規メッセージ相手の上限に達した時、入力欄の代わりにアップグレード導線を出す。
    private var dailyLimitPrompt: some View {
        Button {
            showingMembership = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("本日のメッセージ上限(\(MembershipTier.freeDailyMessagePartnerLimit)人)に達しました")
                        .font(.subheadline.bold())
                    Text("有料会員なら人数制限なくメッセージできます")
                        .font(.caption2)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.brandGradient, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var typingIndicatorRow: some View {
        HStack(spacing: 6) {
            TypingDotsView()
            Text(String.appLocalized("%@さんが入力中...", otherProfile.name.displayNameForCurrentLanguage))
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
                    .foregroundStyle(Color.brandPurple)
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
                Task {
                    let succeeded = await messageManager.send(text: text)
                    if succeeded {
                        await notifyOtherOfNewMessage()
                    } else if draftText.isEmpty {
                        // 送信に失敗した場合、打った文章を消さずに入力欄へ戻す
                        // (その間に別の文章を打ち始めていた場合は上書きしない)。
                        draftText = text
                    }
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.brandPurple)
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messageManager.isSending)
            .accessibilityLabel("送信")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// 通話リクエストの状態をメッセージバブル風に表示する。
/// 自分から送った分は状態表示のみ、相手から届いた分は許可/拒否のボタン付き。
private struct CallRequestBubbleView: View {
    let isMine: Bool
    let name: String
    let status: CallRequestStatus
    var onAccept: (() -> Void)? = nil
    var onDecline: (() -> Void)? = nil

    private var statusText: String {
        switch status {
        case .pending: return isMine ? String.appLocalized("電話をします") : String.appLocalized("%@さんから電話のリクエストです", name)
        case .accepted: return isMine ? String.appLocalized("%@さんが通話を許可しました", name) : String.appLocalized("通話を許可しました")
        case .declined: return isMine ? String.appLocalized("今は難しいようです") : String.appLocalized("リクエストを見送りました")
        case .canceled: return String.appLocalized("通話リクエストを取り消しました")
        }
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    Text(statusText)
                        .font(.subheadline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMine ? Color.brandPurple : Color(.systemGray6))
                .foregroundStyle(isMine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                if !isMine, status == .pending, let onAccept, let onDecline {
                    HStack(spacing: 8) {
                        Button("許可する", action: onAccept)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandPurple, in: Capsule())
                            .foregroundStyle(.white)
                        Button("今は無理", action: onDecline)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                }
            }
            if !isMine { Spacer(minLength: 40) }
        }
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
                            .background(isMine ? Color.brandPurple : Color(.systemGray6))
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

/// 最初のメッセージの候補をいくつか提示し、選んで送るか、下書き欄に入れてカスタマイズできる画面。
/// 実際のAIではなく、お相手の名前・共通の趣味カードから文面をテンプレートで組み立てている
/// (AIBioComposerViewの自己紹介自動生成と同じ考え方)。
private struct FirstMessageComposerSheet: View {
    let otherName: String
    let sharedHobbyCards: [HobbyCard]
    var onSend: (String) -> Void
    var onCustomize: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isGenerating = true
    @State private var options: [MessageOption] = []
    @State private var selectedId: UUID?

    private struct MessageOption: Identifiable {
        let id = UUID()
        let category: String
        let text: String
    }

    private static func generate(otherName: String, sharedHobbyCards: [HobbyCard]) -> [MessageOption] {
        var options: [MessageOption] = []
        if let hobby = sharedHobbyCards.first {
            let suffix = sharedHobbyCards.count > 1 ? "など" : ""
            options.append(MessageOption(
                category: "共通の趣味(おすすめ)",
                text: "\(hobby.emoji)「\(hobby.title)」\(suffix)、私も好きです!共通点があって嬉しいです😊 よろしくお願いします!"
            ))
        }
        options.append(MessageOption(category: "会話のお誘い", text: "すごく気になったのでお話しできたら嬉しいです!よろしくです!"))
        options.append(MessageOption(category: "マッチングの喜び", text: "マッチ嬉しいです!ぜひ仲良くしてください!よろしくお願いします😄"))
        options.append(MessageOption(category: "挨拶(シンプル)", text: "はじめまして\(otherName)さん!よろしくお願いします!"))
        return options
    }

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.brandPurple)
                        Text("お相手に合わせたメッセージを作成中...")
                            .font(.subheadline.bold())
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if !sharedHobbyCards.isEmpty {
                                Text("お二人の共通点から、話題になりそうなメッセージを選びました")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(options) { option in
                                Button {
                                    selectedId = option.id
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(option.category)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.brandPurple.opacity(0.12), in: Capsule())
                                            .foregroundStyle(Color.brandPurple)
                                        Text(option.text)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedId == option.id ? Color.brandPurple : Color(.systemGray5), lineWidth: selectedId == option.id ? 2 : 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 10) {
                            Button {
                                if let text = options.first(where: { $0.id == selectedId })?.text ?? options.first?.text {
                                    onSend(text)
                                }
                            } label: {
                                Text("このまま送信する")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.brandGradient)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            Button("カスタマイズする") {
                                if let text = options.first(where: { $0.id == selectedId })?.text ?? options.first?.text {
                                    onCustomize(text)
                                }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.bar)
                    }
                }
            }
            .navigationTitle("メッセージを選択してください")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .task {
                // 実際に考えているような体感にするため、ごく短い生成中表示を挟む。
                try? await Task.sleep(nanoseconds: 900_000_000)
                options = Self.generate(otherName: otherName, sharedHobbyCards: sharedHobbyCards)
                selectedId = options.first?.id
                withAnimation { isGenerating = false }
            }
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

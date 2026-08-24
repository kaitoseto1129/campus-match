//
//  GatheringDetailView.swift
//  Matching App
//

import SwiftUI

struct GatheringDetailView: View {
    @ObservedObject var manager: GatheringManager
    let summary: GatheringSummary
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var applicants: [(application: GatheringApplication, profile: Profile?, photoURL: URL?)] = []
    @State private var isLoadingApplicants = false
    @State private var showingApplySheet = false
    @State private var showingChat = false
    @State private var toastMessage: String?
    @State private var showingApplyConfirmation = false
    @State private var showingWithdrawConfirm = false

    /// managerの最新状態(応募・承認直後の反映)を都度反映するため、渡された初期値ではなく探し直す。
    private var currentSummary: GatheringSummary {
        (manager.openSummaries + manager.hostedSummaries).first { $0.gathering.id == summary.gathering.id } ?? summary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if currentSummary.isHost {
                    hostApplicantsSection
                }
            }
            .padding()
        }
        .background(Color.appListBackground.ignoresSafeArea())
        .navigationTitle("集まりの詳細")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .actionToast($toastMessage)
        .sentConfirmationCover(isPresented: $showingApplyConfirmation, message: "応募しました", icon: "hand.raised.fill")
        .sheet(isPresented: $showingApplySheet) {
            GatheringApplySheet(summary: currentSummary) { comment in
                Task {
                    let succeeded = await manager.apply(to: currentSummary.gathering, comment: comment)
                    if succeeded {
                        showingApplyConfirmation = true
                    } else {
                        toastMessage = "応募できませんでした"
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingChat) {
            GatheringChatView(gathering: currentSummary.gathering)
        }
        .confirmationDialog("応募を取り消しますか?", isPresented: $showingWithdrawConfirm, titleVisibility: .visible) {
            Button("取り消す", role: .destructive) {
                if let myApplication = currentSummary.myApplication {
                    Task { await manager.withdraw(myApplication) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .task {
            if currentSummary.isHost {
                await loadApplicants()
            }
        }
        .onAppear { tabRouter.pushDetailScreen() }
        .onDisappear { tabRouter.popDetailScreen() }
    }

    private func loadApplicants() async {
        isLoadingApplicants = true
        applicants = await manager.loadApplicantProfiles(for: currentSummary.gathering.id)
        isLoadingApplicants = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let imageURL = currentSummary.gathering.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray6)
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text(currentSummary.gathering.title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            if let category = currentSummary.gathering.category {
                Text(LocalizedStringKey(category))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTeal.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.brandTeal)
            }

            HStack(spacing: 10) {
                IconImage(url: currentSummary.hostPhotoURL, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentSummary.hostProfile?.name.displayNameForCurrentLanguage ?? "-")
                        .font(.subheadline.bold())
                    Text("主催者")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = currentSummary.gathering.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRow(icon: "clock", text: currentSummary.gathering.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                if let durationHours = currentSummary.gathering.durationHours {
                    detailRow(icon: "hourglass", text: String.appLocalized("だいたい%lld時間", durationHours))
                }
                detailRow(icon: "mappin.and.ellipse", text: currentSummary.gathering.location)
                detailRow(icon: "person.2.fill", text: String.appLocalized("%lld/%lld人", currentSummary.currentMemberCount, currentSummary.gathering.capacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandPurple)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hostApplicantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("応募一覧")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if isLoadingApplicants {
                ProgressView().frame(maxWidth: .infinity)
            } else if applicants.isEmpty {
                Text("まだ応募はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(applicants, id: \.application.id) { item in
                        applicantRow(item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func applicantRow(_ item: (application: GatheringApplication, profile: Profile?, photoURL: URL?)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconImage(url: item.photoURL, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.profile?.name.displayNameForCurrentLanguage ?? "-")
                        .font(.subheadline.bold())
                    if let comment = item.application.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusLabel(for: item.application.status)
            }
            if item.application.status == "pending" {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            let succeeded = await manager.respond(to: item.application, gathering: currentSummary.gathering, accept: true)
                            toastMessage = succeeded ? "承認しました" : "承認できませんでした"
                            await loadApplicants()
                        }
                    } label: {
                        Text("承認する")
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.brandPurple, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Button {
                        Task {
                            let succeeded = await manager.respond(to: item.application, gathering: currentSummary.gathering, accept: false)
                            toastMessage = succeeded ? "見送りました" : "操作に失敗しました"
                            await loadApplicants()
                        }
                    } label: {
                        Text("見送る")
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusLabel(for status: String) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case "accepted": return ("参加確定", Color.brandTeal)
            case "declined": return ("見送り", Color(.systemGray))
            case "canceled": return ("取り消し", Color(.systemGray))
            default: return ("承認待ち", Color.brandOrange)
            }
        }()
        return Text(LocalizedStringKey(text))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        let s = currentSummary
        Group {
            if s.isMember {
                Button {
                    showingChat = true
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("グループトークを開く").bold()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            } else if let myApplication = s.myApplication {
                switch myApplication.status {
                case "pending":
                    Button {
                        showingWithdrawConfirm = true
                    } label: {
                        Text("応募を取り消す")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                case "declined":
                    Text("今回は参加が見送られました")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                default:
                    EmptyView()
                }
            } else if !s.gathering.isOpen || s.isFull {
                Text("満員になりました")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            } else {
                Button {
                    showingApplySheet = true
                } label: {
                    Text("応募する")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.bar)
    }
}

/// 応募シート。以前はただのForm+ツールバーボタンで素っ気なかったため、
/// 他の送信系シート(FilterSheetViewの検索ボタンなど)と統一感のあるカードデザインにしている。
private struct GatheringApplySheet: View {
    let summary: GatheringSummary
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            IconImage(url: summary.hostPhotoURL, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.gathering.title)
                                    .font(.subheadline.bold())
                                    .lineLimit(2)
                                Text(summary.hostProfile?.name.displayNameForCurrentLanguage ?? "-")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("一言コメント(任意)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        TextField("一緒に参加したい理由や自己紹介など", text: $comment, axis: .vertical)
                            .lineLimit(4...8)
                            .padding(12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .background(Color.appListBackground.ignoresSafeArea())
            .navigationTitle("応募する")
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
            .safeAreaInset(edge: .bottom) {
                Button {
                    onSubmit(comment.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                } label: {
                    Text("応募する")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

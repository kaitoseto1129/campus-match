//
//  GatheringListView.swift
//  Matching App
//

import SwiftUI

struct GatheringListView: View {
    @StateObject private var manager = GatheringManager()
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var selectedSegment: Segment = .browse
    @State private var browseSubSegment: BrowseSubSegment = .all
    @State private var showingCreateSheet = false
    @State private var showingFilterSheet = false
    @State private var filter = GatheringBrowseFilter()
    @State private var navPath = NavigationPath()
    @AppStorage("hasSeenGatheringTutorial") private var hasSeenGatheringTutorial = false
    @State private var tutorialStep: GatheringTutorialStep?
    @State private var tutorialAnchors: [String: Anchor<CGRect>] = [:]

    enum Segment: String, CaseIterable {
        case browse, hosted
        var label: String {
            switch self {
            case .browse: return "みんなの募集"
            case .hosted: return "自分が主催"
            }
        }
    }

    /// 「みんなの募集」内で、まだ応募していないものと自分が応募済みのものを分けて見られるようにする
    /// (以前は一つのリストに混ざっていて、自分が応募したものがどれか探しにくかった)。
    enum BrowseSubSegment: String, CaseIterable {
        case all, applied
        var label: String {
            switch self {
            case .all: return "一覧"
            case .applied: return "参加依頼済み"
            }
        }
    }

    private var visibleSummaries: [GatheringSummary] {
        switch selectedSegment {
        case .browse:
            let base = filter.isActive ? manager.openSummaries.filter(filter.matches) : manager.openSummaries
            switch browseSubSegment {
            case .all: return base
            case .applied: return base.filter { $0.myApplication != nil }
            }
        case .hosted:
            return manager.hostedSummaries
        }
    }

    var body: some View {
        ZStack {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("", selection: $selectedSegment) {
                        ForEach(Segment.allCases, id: \.self) { segment in
                            Text(LocalizedStringKey(segment.label)).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .tutorialAnchor("gatheringSegments")

                    if selectedSegment == .browse {
                        Picker("", selection: $browseSubSegment) {
                            ForEach(BrowseSubSegment.allCases, id: \.self) { sub in
                                Text(LocalizedStringKey(sub.label)).tag(sub)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        filterBar
                    }

                    if manager.isLoading && visibleSummaries.isEmpty {
                        ProgressView().padding(.top, 60)
                    } else if visibleSummaries.isEmpty {
                        emptyState
                    } else {
                        // YouTubeの一覧と同じく、サムネイルを左右いっぱいに使い、
                        // カードの枠や影は付けずに並べる。
                        LazyVStack(spacing: 24) {
                            ForEach(visibleSummaries) { summary in
                                NavigationLink(value: summary.gathering.id) {
                                    GatheringCard(summary: summary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("集まり")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.brandPurple)
                    }
                    .tutorialAnchor("gatheringCreate")
                }
            }
            .refreshable {
                await manager.load()
            }
            .task {
                await manager.load()
                let isEligible = UserDefaults.standard.bool(forKey: AuthManager.eligibleForOnboardingTutorialKey)
                if isEligible && !hasSeenGatheringTutorial {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation { tutorialStep = .segments }
                }
            }
            .onPreferenceChange(TutorialAnchorKey.self) { tutorialAnchors = $0 }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                Task { await manager.load() }
            }) {
                CreateGatheringView(manager: manager)
            }
            .sheet(isPresented: $showingFilterSheet) {
                GatheringFilterSheet(filter: $filter)
            }
            .navigationDestination(for: UUID.self) { gatheringId in
                if let summary = (manager.openSummaries + manager.hostedSummaries).first(where: { $0.gathering.id == gatheringId }) {
                    GatheringDetailView(manager: manager, summary: summary)
                }
            }
            .onChange(of: tabRouter.popToRootTokens[.gatherings]) { _, _ in
                navPath = NavigationPath()
            }
            .alert("読み込めませんでした", isPresented: Binding(
                get: { manager.errorMessage != nil },
                set: { if !$0 { manager.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(manager.errorMessage ?? ""))
            }
        }
        if tutorialStep != nil {
            GatheringTutorialOverlay(step: $tutorialStep, anchors: tutorialAnchors) {
                hasSeenGatheringTutorial = true
            }
        }
        }
    }

    private var filterBar: some View {
        HStack {
            Button {
                showingFilterSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle" + (filter.isActive ? ".fill" : ""))
                    Text("絞り込み")
                }
                .font(.subheadline.bold())
                .foregroundStyle(filter.isActive ? .white : Color.brandPurple)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(filter.isActive ? AnyShapeStyle(Color.brandPurple) : AnyShapeStyle(Color.brandPurple.opacity(0.12)), in: Capsule())
            }
            if filter.isActive {
                Button {
                    filter = GatheringBrowseFilter()
                } label: {
                    Text("リセット")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var emptyStateText: String {
        switch selectedSegment {
        case .browse:
            return browseSubSegment == .applied ? "まだ応募した集まりはありません" : "募集中の集まりはまだありません"
        case .hosted:
            return "まだ主催した集まりはありません"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(emptyStateText))
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            if selectedSegment == .browse && browseSubSegment == .all {
                Text("右上の+から、ご飯や集まりを募集してみましょう")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// 集まり1件のカード。YouTubeの一覧と同じ組み立てにしている。
/// 16:9のサムネイルを大きく見せ、その下にアバターとテキストを置く。
/// 写真は募集時の必須項目なので、基本的にサムネイルは必ず入る
/// (写真必須になる前に作られた集まりのためにプレースホルダーは残してある)。
private struct GatheringCard: View {
    let summary: GatheringSummary

    /// 主催している集まりに承認待ちの応募が来ているかどうか。
    private var pendingApplicationBadge: Int? {
        guard summary.isHost, !summary.gathering.isCanceled, summary.pendingCount > 0 else { return nil }
        return summary.pendingCount
    }

    private var statusBadge: (text: String, color: Color)? {
        if summary.gathering.isCanceled { return ("キャンセル済み", Color(.systemGray)) }
        if summary.isHost { return nil }
        switch summary.myApplication?.status {
        case "pending": return ("承認待ち", Color.brandOrange)
        case "accepted": return ("参加確定", Color.brandTeal)
        case "declined": return ("見送り", Color(.systemGray))
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            details
        }
    }

    private var thumbnail: some View {
        ZStack {
            if let imageURL = summary.gathering.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        Color(.systemGray6)
                    }
                }
            } else {
                placeholder
            }
        }
        .aspectRatio(16 / 9, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // 状態は写真の上に重ねる。YouTubeの「ライブ」バッジと同じ位置・見た目。
        .overlay(alignment: .topLeading) {
            if let pendingApplicationBadge {
                overlayChip(
                    text: String.appLocalized("応募%lld件", pendingApplicationBadge),
                    systemImage: "bell.fill",
                    background: Color.brandOrange
                )
                .padding(8)
            } else if let statusBadge {
                overlayChip(text: statusBadge.text, systemImage: nil, background: statusBadge.color)
                    .padding(8)
            }
        }
        // 参加人数は、YouTubeで動画の長さが出る位置に置く。
        .overlay(alignment: .bottomTrailing) {
            overlayChip(
                text: String.appLocalized("%lld/%lld人", summary.currentMemberCount, summary.gathering.capacity),
                systemImage: "person.2.fill",
                background: .black.opacity(0.75)
            )
            .padding(8)
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.systemGray6)
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(Color(.systemGray3))
        }
    }

    private func overlayChip(text: String, systemImage: String?, background: Color) -> some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(LocalizedStringKey(text))
        }
        .font(.caption2.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(background, in: RoundedRectangle(cornerRadius: 6))
    }

    private var details: some View {
        HStack(alignment: .top, spacing: 12) {
            IconImage(url: summary.hostPhotoURL, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.gathering.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.hostProfile?.name.displayNameForCurrentLanguage ?? "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 日時・場所・カテゴリを、YouTubeの「再生回数・投稿日」と同じ1行のメタ情報にまとめる。
                HStack(spacing: 4) {
                    Text(summary.gathering.scheduledAt, format: .dateTime.month().day().hour().minute())
                    Text("・")
                    Text(summary.gathering.location)
                    if let category = summary.gathering.category {
                        Text("・")
                        Text(LocalizedStringKey(category))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .padding(.horizontal, 12)
    }
}

private struct GatheringFilterSheet: View {
    @Binding var filter: GatheringBrowseFilter
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GatheringBrowseFilter

    init(filter: Binding<GatheringBrowseFilter>) {
        self._filter = filter
        self._draft = State(initialValue: filter.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("日付で絞り込む") {
                    Toggle("日付を指定", isOn: Binding(
                        get: { draft.date != nil },
                        set: { draft.date = $0 ? (draft.date ?? Date()) : nil }
                    ))
                    if let date = draft.date {
                        DatePicker("この日に開催", selection: Binding(get: { date }, set: { draft.date = $0 }), displayedComponents: [.date])
                    }
                }
                Section("カテゴリで絞り込む") {
                    ForEach(gatheringCategoryOptions, id: \.self) { category in
                        Button {
                            if draft.categories.contains(category) {
                                draft.categories.remove(category)
                            } else {
                                draft.categories.insert(category)
                            }
                        } label: {
                            HStack {
                                Text(LocalizedStringKey(category)).foregroundStyle(.primary)
                                Spacer()
                                if draft.categories.contains(category) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        filter = draft
                        dismiss()
                    } label: {
                        Text("適用する").bold()
                    }
                }
            }
        }
    }
}

#Preview {
    GatheringListView()
        .environmentObject(TabRouter())
}

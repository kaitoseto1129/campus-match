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
                        LazyVStack(spacing: 12) {
                            ForEach(visibleSummaries) { summary in
                                NavigationLink(value: summary.gathering.id) {
                                    GatheringCard(summary: summary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.appListBackground.ignoresSafeArea())
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

private struct GatheringCard: View {
    let summary: GatheringSummary

    /// 主催している集まりに承認待ちの応募が来ているかどうか。
    /// 他のステータス表示(承認待ち/参加確定など)と同じ薄いピル型バッジだと、
    /// 「対応が必要な通知」なのか「単なる状態表示」なのか見分けがつかず気付きにくかったため、
    /// これだけは別枠の目立つ丸バッジで出す。
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
        VStack(alignment: .leading, spacing: 10) {
            if let imageURL = summary.gathering.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray6)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.gathering.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let category = summary.gathering.category {
                        Text(LocalizedStringKey(category))
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.brandTeal.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.brandTeal)
                    }
                }
                Spacer()
                if let pendingApplicationBadge {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                        Text(String.appLocalized("応募%lld件", pendingApplicationBadge))
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandOrange, in: Capsule())
                    .shadow(color: Color.brandOrange.opacity(0.4), radius: 4, y: 2)
                } else if let statusBadge {
                    Text(LocalizedStringKey(statusBadge.text))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusBadge.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusBadge.color)
                }
            }

            HStack(spacing: 12) {
                Label {
                    Text(summary.gathering.scheduledAt, format: .dateTime.month().day().hour().minute())
                } icon: {
                    Image(systemName: "clock")
                }
                Label {
                    Text(summary.gathering.location)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                IconImage(url: summary.hostPhotoURL, size: 28)
                Text(summary.hostProfile?.name.displayNameForCurrentLanguage ?? "-")
                    .font(.caption.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                    Text(String.appLocalized("%lld/%lld人", summary.currentMemberCount, summary.gathering.capacity))
                }
                .font(.caption.bold())
                .foregroundStyle(summary.isFull ? Color(.systemGray) : Color.brandPurple)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
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

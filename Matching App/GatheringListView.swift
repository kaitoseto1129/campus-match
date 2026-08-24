//
//  GatheringListView.swift
//  Matching App
//

import SwiftUI

struct GatheringListView: View {
    @StateObject private var manager = GatheringManager()
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var selectedSegment: Segment = .browse
    @State private var showingCreateSheet = false
    @State private var navPath = NavigationPath()

    enum Segment: String, CaseIterable {
        case browse, mine
        var label: String {
            switch self {
            case .browse: return "みんなの募集"
            case .mine: return "自分の集まり"
            }
        }
    }

    private var visibleSummaries: [GatheringSummary] {
        selectedSegment == .browse ? manager.openSummaries : manager.mySummaries
    }

    var body: some View {
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
                }
            }
            .refreshable {
                await manager.load()
            }
            .task {
                await manager.load()
            }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                Task { await manager.load() }
            }) {
                CreateGatheringView(manager: manager)
            }
            .navigationDestination(for: UUID.self) { gatheringId in
                if let summary = (manager.openSummaries + manager.mySummaries).first(where: { $0.gathering.id == gatheringId }) {
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
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(selectedSegment == .browse ? "募集中の集まりはまだありません" : "参加中・主催中の集まりはありません"))
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            if selectedSegment == .browse {
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

    private var statusBadge: (text: String, color: Color)? {
        if summary.isHost { return ("主催中", Color.brandPurple) }
        switch summary.myApplication?.status {
        case "pending": return ("承認待ち", Color.brandOrange)
        case "accepted": return ("参加確定", Color.brandTeal)
        case "declined": return ("見送り", Color(.systemGray))
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(summary.gathering.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
                if let statusBadge {
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
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

#Preview {
    GatheringListView()
        .environmentObject(TabRouter())
}

//
//  ModerationAdminView.swift
//  Matching App
//

import SwiftUI

/// マイページの「通報管理」から、is_admin = true のユーザーだけが開ける簡易モデレーション画面。
/// 通報への対応に加えて、利用規約 第5条3項で約束している「募集内容の継続的な確認」を
/// 実際に行うための、集まりの募集一覧も持つ。
struct ModerationAdminView: View {
    @StateObject private var manager = ModerationAdminManager()
    @State private var tab: Tab = .reports

    enum Tab: String, CaseIterable {
        case reports = "通報"
        case gatherings = "集まりの募集"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollView {
                switch tab {
                case .reports:
                    if manager.items.isEmpty && !manager.isLoading {
                        emptyText("通報はまだありません")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(manager.items) { item in
                                ReportRow(manager: manager, item: item)
                            }
                        }
                        .padding()
                    }
                case .gatherings:
                    if manager.gatheringItems.isEmpty && !manager.isLoading {
                        emptyText("集まりの募集はまだありません")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(manager.gatheringItems) { item in
                                AdminGatheringRow(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .refreshable {
                await reload()
            }
        }
        .background(Color.appListBackground.ignoresSafeArea())
        .navigationTitle("通報管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await manager.load()
        }
        .onChange(of: tab) { _, _ in
            Task { await reload() }
        }
    }

    private func emptyText(_ message: String) -> some View {
        Text(LocalizedStringKey(message))
            .foregroundStyle(.secondary)
            .padding(.top, 60)
    }

    private func reload() async {
        switch tab {
        case .reports: await manager.load()
        case .gatherings: await manager.loadGatherings()
        }
    }
}

/// 集まりの募集1件。募集文をそのまま読めるようにし、フィルタに引っかかる内容には印を付ける。
private struct AdminGatheringRow: View {
    let item: AdminGatheringItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let hostProfile = item.hostProfile {
                        NavigationLink {
                            OtherUserProfileView(profile: hostProfile) { EmptyView() }
                        } label: {
                            IconImage(url: item.hostPhotoURL, size: 48)
                        }
                    } else {
                        IconImage(url: item.hostPhotoURL, size: 48)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.gathering.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                    Text("主催: \(item.hostProfile?.name ?? "不明なユーザー")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if item.gathering.isCanceled {
                    Text("中止")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            if let flagged = item.flagged {
                Label(flagged.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
            }

            if let description = item.gathering.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Text("\(item.gathering.location) ・ 定員\(item.gathering.capacity)人")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.gathering.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ReportRow: View {
    @ObservedObject var manager: ModerationAdminManager
    let item: AdminReportItem
    @State private var isResolving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let reportedProfile = item.reportedProfile {
                        NavigationLink {
                            OtherUserProfileView(profile: reportedProfile) { EmptyView() }
                        } label: {
                            IconImage(url: item.reportedPhotoURL, size: 48)
                        }
                    } else {
                        IconImage(url: item.reportedPhotoURL, size: 48)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("通報対象: \(item.reportedProfile?.name ?? "不明なユーザー")")
                        .font(.subheadline.bold())
                    Text("通報者: \(item.reporterProfile?.name ?? "不明なユーザー")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if item.report.resolved {
                    Text("対応済み")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            if let reason = item.report.reason, !reason.isEmpty {
                Text(LocalizedStringKey(reason))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Text(item.report.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if !item.report.resolved {
                    Button {
                        Task {
                            isResolving = true
                            await manager.markResolved(item.report)
                            isResolving = false
                        }
                    } label: {
                        Text("対応済みにする")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandPurple, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .disabled(isResolving)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        ModerationAdminView()
    }
}

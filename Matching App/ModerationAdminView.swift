//
//  ModerationAdminView.swift
//  Matching App
//

import SwiftUI

/// マイページの「通報管理」から、is_admin = true のユーザーだけが開ける簡易モデレーション画面。
struct ModerationAdminView: View {
    @StateObject private var manager = ModerationAdminManager()

    var body: some View {
        ScrollView {
            if manager.items.isEmpty && !manager.isLoading {
                Text("通報はまだありません")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(manager.items) { item in
                        ReportRow(manager: manager, item: item)
                    }
                }
                .padding()
            }
        }
        .background(Color.appListBackground.ignoresSafeArea())
        .navigationTitle("通報管理")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await manager.load()
        }
        .task {
            await manager.load()
        }
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
                Text(reason)
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
                            .background(Color.brandBlue, in: Capsule())
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

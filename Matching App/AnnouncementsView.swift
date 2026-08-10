//
//  AnnouncementsView.swift
//  Matching App
//

import SwiftUI

private struct Announcement: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let body: String
}

private let sampleAnnouncements: [Announcement] = [
    Announcement(title: "ようこそマッチングアプリへ", date: "2026/08/01", body: "プロフィールを充実させて、素敵な出会いを見つけましょう。"),
    Announcement(title: "プロフィール写真のガイドライン", date: "2026/08/03", body: "顔がはっきり写っている写真を設定すると、いいねが届きやすくなります。"),
    Announcement(title: "メンテナンスのお知らせ", date: "2026/08/10", body: "サービス品質向上のため、定期メンテナンスを実施することがあります。"),
]

struct AnnouncementsView: View {
    var body: some View {
        List(sampleAnnouncements) { announcement in
            VStack(alignment: .leading, spacing: 6) {
                Text(announcement.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(announcement.title)
                    .font(.headline)
                Text(announcement.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .listStyle(.plain)
        .navigationTitle("お知らせ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AnnouncementsView()
    }
}

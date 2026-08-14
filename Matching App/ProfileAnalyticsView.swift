//
//  ProfileAnalyticsView.swift
//  Matching App
//

import SwiftUI
import Charts

struct ProfileAnalyticsView: View {
    @StateObject private var manager = ProfileAnalyticsManager()

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.brandPurple.opacity(0.35), Color.brandTeal.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCards
                    insightsCard
                    photoStatsCard
                    sectionFunnelCard
                }
                .padding()
            }
            .refreshable {
                await manager.load()
            }
        }
        .background(Color.appListBackground.ignoresSafeArea())
        .navigationTitle("プロフィール分析")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await manager.load()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("プロフィールの反応をチェック")
                    .font(.headline)
                Text("閲覧数やいいねの傾向から、改善のヒントを確認できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    /// 閲覧数のうち何%がいいねにつながったか。母数(閲覧数)が0の間は算出しない。
    private var likeRatePercent: Int? {
        guard manager.totalVisits > 0 else { return nil }
        return Int((Double(manager.totalLikesReceived) / Double(manager.totalVisits) * 100).rounded())
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(icon: "eye.fill", color: Color.brandTeal, title: "プロフィール閲覧数", value: "\(manager.totalVisits)")
                statCard(icon: "hand.thumbsup.fill", color: Color.brandPurple, title: "受け取ったいいね", value: "\(manager.totalLikesReceived)")
            }
            if let likeRatePercent {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 46, height: 46)
                        Image(systemName: "percent")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("いいね獲得率")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.85))
                        Text("閲覧した人の\(likeRatePercent)%がいいねを送っています")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    Text("\(likeRatePercent)%")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding()
                .background(
                    LinearGradient(colors: [Color.brandPurple, Color.brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: Color.brandPurple.opacity(0.25), radius: 10, y: 4)
            }
        }
    }

    private func statCard(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    /// カードの見出しをアイコン付きの丸バッジで統一し、他のカードと同じ「デザインされた」印象にする。
    private func cardHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.headline)
        }
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "sparkles", color: Color.brandOrange, title: "改善のヒント")
            if manager.isLoading && manager.insights.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if manager.insights.isEmpty {
                Text("データが増えると、ここに改善のヒントが表示されます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(manager.insights.enumerated()), id: \.offset) { _, text in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.brandOrange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private var photoStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "photo.on.rectangle.angled", color: Color.brandTeal, title: "写真ごとの閲覧数")
            if manager.photoStats.isEmpty {
                Text("写真がまだ登録されていません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(Array(manager.photoStats.enumerated()), id: \.element.id) { index, stat in
                    BarMark(
                        x: .value("閲覧数", stat.viewCount),
                        y: .value("写真", index == 0 ? "メイン" : "\(index + 1)枚目")
                    )
                    .foregroundStyle(index == 0 ? Color.brandPurple : Color.brandTeal)
                    .cornerRadius(6)
                    .annotation(position: .trailing) {
                        Text("\(stat.viewCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(manager.photoStats.count) * 40 + 20)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private var sectionFunnelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "arrow.down.right.and.arrow.up.left", color: Color.brandPurple, title: "どこまで読まれているか")
            Text("到達した割合が低いほど、その手前で離脱している人が多いことを示します")
                .font(.caption)
                .foregroundStyle(.secondary)

            if manager.sectionStats.isEmpty {
                Text("データがまだありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(manager.sectionStats) { stat in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(stat.section.label)
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(Int(stat.percentage * 100))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.brandTeal)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemGray5))
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.brandGradient)
                                        .frame(width: geo.size.width * stat.percentage)
                                }
                            }
                            .frame(height: 10)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

#Preview {
    NavigationStack {
        ProfileAnalyticsView()
    }
}

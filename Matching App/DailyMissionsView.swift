//
//  DailyMissionsView.swift
//  Matching App
//

import SwiftUI

struct DailyMissionsView: View {
    @StateObject private var manager = DailyMissionsManager()
    @Environment(\.dismiss) private var dismiss
    /// 探す画面の初回チュートリアル中に開かれた場合、ログインボーナス受け取り後に
    /// 「右上の閉じるボタンを押して次へ」の案内を出す。
    var showsTutorialHint: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if showsTutorialHint && manager.claimedKeys.contains("login") {
                        tutorialCloseHint
                    }
                    ForEach(manager.missions) { mission in
                        MissionCardView(manager: manager, mission: mission)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("デイリーミッション")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await manager.load()
            }
            .refreshable {
                await manager.load()
            }
        }
    }

    private var tutorialCloseHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.right")
            Text("受け取れました!右上の「閉じる」を押して次へ進みましょう")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.brandOrange, in: RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("素敵なお相手と出会うには毎日の積みかさねが大切!")
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text("達成すると無料でいいねがもらえます")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [Color.brandTeal, Color.brandTeal.opacity(0.75)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}

private struct MissionCardView: View {
    @ObservedObject var manager: DailyMissionsManager
    let mission: MissionProgress
    @State private var isClaiming = false

    private var isClaimed: Bool { manager.claimedKeys.contains(mission.key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(mission.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if mission.isComplete {
                    Text("CLEAR!")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "hand.thumbsup.fill")
                Text("+\(mission.reward)いいね")
            }
            .font(.caption.bold())
            .foregroundStyle(Color.brandPurple)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white, in: Capsule())

            HStack(spacing: 10) {
                ProgressView(value: Double(mission.current), total: Double(mission.target))
                    .tint(.white)
                Text("\(mission.current)/\(mission.target)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)

                Button {
                    Task {
                        isClaiming = true
                        await manager.claim(mission)
                        isClaiming = false
                    }
                } label: {
                    Text(isClaimed ? "受取済み" : "受け取る")
                        .font(.caption.bold())
                        .foregroundStyle(mission.isComplete && !isClaimed ? Color.brandPurple : .white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(mission.isComplete && !isClaimed ? .white : Color.black.opacity(0.25), in: Capsule())
                }
                .disabled(!mission.isComplete || isClaimed || isClaiming)
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.brandPurple, Color.brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

#Preview {
    DailyMissionsView()
}

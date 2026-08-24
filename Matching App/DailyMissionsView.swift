//
//  DailyMissionsView.swift
//  Matching App
//

import SwiftUI

struct DailyMissionsView: View {
    @StateObject private var manager = DailyMissionsManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabRouter: TabRouter
    /// 探す画面の初回チュートリアル中に開かれた場合、ログインボーナスの受け取るボタンを
    /// 光らせて案内し、受け取り後は「右上の閉じるボタンを押して次へ」の案内を出す。
    var showsTutorialHint: Bool = false
    @State private var showingClaimedToast = false
    @State private var claimedToastMessage = "いいねを受け取りました!"
    @State private var isClaimingAll = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if showsTutorialHint && !manager.claimedKeys.contains("login") {
                            tutorialTapHint
                        }
                        if showsTutorialHint && manager.claimedKeys.contains("login") {
                            tutorialCloseHint
                        }
                        ForEach(manager.missions) { mission in
                            MissionCardView(
                                manager: manager,
                                mission: mission,
                                highlightClaim: showsTutorialHint && mission.key == "login",
                                onClaimed: {
                                    showClaimedToast(message: "いいねを受け取りました!")
                                    // チュートリアル中は、受け取れたらそのまま次のステップへ進めるよう自動で閉じる。
                                    // (以前は「閉じる」を自分で探して押す必要があり、そこで迷いやすかった)
                                    if showsTutorialHint && mission.key == "login" {
                                        Task {
                                            try? await Task.sleep(nanoseconds: 1_300_000_000)
                                            dismiss()
                                        }
                                    }
                                },
                                // 未達成のミッションは、達成できる画面(探す)へそのまま送る。
                                onGoToAction: {
                                    tabRouter.selectTab(.discover)
                                    dismiss()
                                }
                            )
                        }
                        if manager.hasClaimableMission {
                            // 下の浮きボタンと重ならないよう、リストの最後に余白を足しておく。
                            Color.clear.frame(height: 60)
                        }
                    }
                    .padding()
                }

                if manager.hasClaimableMission {
                    claimAllButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
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
            .sentConfirmationCover(isPresented: $showingClaimedToast, message: claimedToastMessage, icon: "gift.fill")
        }
    }

    private var claimAllButton: some View {
        Button {
            guard !isClaimingAll else { return }
            isClaimingAll = true
            Task {
                let claimableCount = manager.missions.filter { $0.isComplete && !manager.claimedKeys.contains($0.key) }.count
                await manager.claimAll()
                isClaimingAll = false
                if claimableCount > 0 {
                    showClaimedToast(message: "\(claimableCount)件のミッション報酬を受け取りました!")
                }
            }
        } label: {
            HStack(spacing: 6) {
                if isClaimingAll {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "gift.fill")
                }
                Text("全て受け取る")
                    .bold()
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.brandGradient, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .disabled(isClaimingAll)
    }

    /// 以前は受取確認トーストをtrueにするだけでfalseに戻す処理がなく、透明とはいえ
    /// fullScreenCoverが画面を覆ったままになり、右上の「閉じる」が反応しなくなっていた。
    private func showClaimedToast(message: String) {
        claimedToastMessage = message
        showingClaimedToast = true
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            showingClaimedToast = false
        }
    }

    private var tutorialTapHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
            Text("ログインボーナスの「受け取る」をタップしてみましょう")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.brandOrange, in: RoundedRectangle(cornerRadius: 14))
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
    /// チュートリアル中、このミッションの受け取るボタンを指差して案内する。
    var highlightClaim: Bool = false
    var onClaimed: (() -> Void)? = nil
    /// 未達成のミッションから、達成できる画面へ移動するためのコールバック。
    var onGoToAction: (() -> Void)? = nil
    @State private var isClaiming = false
    @State private var pulse = false

    private var isClaimed: Bool { manager.claimedKeys.contains(mission.key) }
    /// 達成済みでまだ受け取っていない状態(=一番目立たせたい、押すべき状態)。
    private var isClaimable: Bool { mission.isComplete && !isClaimed }

    /// 状態(未達成/受取可能/受取済み)がひと目で分かるよう、カード全体の色みを変える。
    /// 以前は3状態とも同じ紫〜ティールのグラデーションだったため、どれが「押すべきか」分かりにくかった。
    private var cardBackground: some ShapeStyle {
        if isClaimed {
            return AnyShapeStyle(Color(.systemGray5))
        } else if isClaimable {
            return AnyShapeStyle(LinearGradient(colors: [Color.brandOrange, Color.brandPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            return AnyShapeStyle(LinearGradient(colors: [Color.brandPurple.opacity(0.55), Color.brandTeal.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
    private var foreground: Color { isClaimed ? .secondary : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey(mission.title))
                    .font(.headline)
                    .foregroundStyle(foreground)
                Spacer()
                if isClaimed {
                    Label("受取済み", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else if mission.isComplete {
                    Text("CLEAR!")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(.white)
                    VStack(spacing: -1) {
                        Text("+\(mission.reward)")
                            .font(.subheadline.bold())
                        Text("いいね")
                            .font(.system(size: 8).bold())
                    }
                    .foregroundStyle(Color.brandPurple)
                }
                .frame(width: 46, height: 46)
                .opacity(isClaimed ? 0.5 : 1)

                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(foreground.opacity(0.85))

                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                    Text(isClaimed ? "受け取り済みです" : "達成でいいねGET!")
                }
                .font(.caption.bold())
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(isClaimed ? 0.4 : 0.18), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                ProgressView(value: Double(mission.current), total: Double(mission.target))
                    .tint(isClaimed ? Color(.systemGray) : .white)
                Text("\(mission.current)/\(mission.target)")
                    .font(.caption.bold())
                    .foregroundStyle(foreground)

                ZStack {
                    if highlightClaim && isClaimable {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .scaleEffect(pulse ? 1.35 : 1.0)
                            .opacity(pulse ? 0 : 0.9)
                            .frame(width: 60, height: 60)
                            .allowsHitTesting(false)
                    }
                    Button {
                        guard !isClaiming else { return }
                        isClaiming = true
                        Task {
                            await manager.claim(mission)
                            isClaiming = false
                            if manager.claimedKeys.contains(mission.key) {
                                onClaimed?()
                            }
                        }
                    } label: {
                        Text(isClaimed ? "受取済み" : "受け取る")
                            .font(.caption.bold())
                            .foregroundStyle(isClaimable ? Color.brandPurple : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isClaimable ? .white : Color.black.opacity(0.25), in: Capsule())
                    }
                    .disabled(!mission.isComplete || isClaimed || isClaiming)
                }
            }

            // まだ達成していないミッションは、どこで達成できるのかが分かりにくかったため、
            // その場から達成できる画面へ移動できるボタンを出す。
            if !mission.isComplete, let actionLabel = mission.actionLabel, let onGoToAction {
                Button(action: onGoToAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.forward.circle.fill")
                        Text(actionLabel)
                            .bold()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.brandPurple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(.white, in: Capsule())
                }
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isClaimable {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandOrange, lineWidth: 2)
            }
        }
        .shadow(color: isClaimable ? Color.brandOrange.opacity(0.4) : .clear, radius: 10, y: 4)
        .sensoryFeedback(.success, trigger: isClaimed) { oldValue, newValue in
            newValue && !oldValue
        }
        .onAppear {
            if isClaimable {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

#Preview {
    DailyMissionsView()
        .environmentObject(TabRouter())
}

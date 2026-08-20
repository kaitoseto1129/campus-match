//
//  DiscoverTutorialOverlay.swift
//  Matching App
//

import SwiftUI

/// 探す画面の初回チュートリアルでハイライトしたい要素の位置を集めるためのPreferenceKey。
struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// この要素をチュートリアルのスポットライト対象として登録する。
    func tutorialAnchor(_ id: String) -> some View {
        anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

enum DiscoverTutorialStep: Equatable {
    case missions
    case filter
    case candidate
    case myPageGuide
    case closing
}

/// 背景を暗転させつつ、対象の四角形だけくり抜いて実際のUIをそのまま操作できるようにするScrim。
private struct SpotlightScrimShape: Shape {
    let holeRect: CGRect
    var cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        guard holeRect != .zero else { return path }
        let inset = holeRect.insetBy(dx: -8, dy: -8)
        path.addPath(Path(roundedRect: inset, cornerRadius: cornerRadius))
        return path
    }
}

/// 探す画面を初めて開いたユーザー向けの簡易チュートリアル。
/// デイリーミッション → 絞り込み → ダミーの候補カードでいいね送信、の順に案内する。
/// 実際のUI(ミッション・絞り込み)はそのまま操作でき、候補カードだけはシミュレーションで
/// 実際のいいねは消費しない。いいねを送ってもカードは消えない(ここが今回の要件)。
struct DiscoverTutorialOverlay: View {
    @Binding var step: DiscoverTutorialStep?
    let anchors: [String: Anchor<CGRect>]
    /// 「マイページを見てみる」を選んだ時にタブを切り替えるために使う。
    var onGoToMyPage: () -> Void
    var onFinish: () -> Void

    @State private var showingFakeProfile = false
    @State private var simulatedLiked = false
    @State private var simulatedHidden = false
    @State private var spotlightPulse = false
    /// 体験用のダミー顔写真。アプリ内の他のダミーアカウントと同じ生成アバターサービスを使い、
    /// 一般的な人物アイコンではなくちゃんと「顔」に見えるようにしている。
    private static let sampleAvatarURL = URL(string: "https://api.dicebear.com/9.x/adventurer/png?seed=tutorial-sample&size=400&backgroundColor=ffd5dc,ffdfbf,c0aede,d1d4f9,b6e3f4")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch step {
                case .missions:
                    spotlight(id: "missions", proxy: proxy) {
                        tooltip(
                            text: "まずはここをタップして、今日のデイリーミッションとログインボーナスを確認しましょう!",
                            anchorId: "missions",
                            proxy: proxy
                        )
                    }
                case .filter:
                    spotlight(id: "filter", proxy: proxy) {
                        tooltip(
                            text: "ここから条件(年齢・居住地・大学など)で絞り込み検索ができます。試しに開いてみましょう。",
                            anchorId: "filter",
                            proxy: proxy
                        )
                    }
                case .candidate:
                    candidateSimulation(proxy: proxy)
                case .myPageGuide:
                    myPageGuideMessage
                case .closing:
                    closingMessage
                case .none:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .sheet(isPresented: $showingFakeProfile) {
            fakeProfileSheet
        }
    }

    // MARK: - スポットライト(実UIをそのまま操作させるステップ)

    @ViewBuilder
    private func spotlight<Content: View>(id: String, proxy: GeometryProxy, @ViewBuilder tooltip: () -> Content) -> some View {
        let rect = anchors[id].map { proxy[$0] } ?? .zero
        ZStack {
            SpotlightScrimShape(holeRect: rect)
                .fill(Color.black.opacity(0.68), style: FillStyle(eoFill: true))
            if rect != .zero {
                // どこを押せばいいのか一目で分かるよう、枠を点滅ではなく脈打つように広げて
                // 「ここです」と指し示す動きを付けている。
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.brandPurple, lineWidth: 3)
                    .frame(width: rect.width + 16, height: rect.height + 16)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                    .shadow(color: Color.brandPurple.opacity(0.6), radius: 10)
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.brandOrange, lineWidth: 3)
                    .frame(width: rect.width + 16, height: rect.height + 16)
                    .scaleEffect(spotlightPulse ? 1.14 : 1.0)
                    .opacity(spotlightPulse ? 0 : 1)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .position(x: rect.maxX, y: rect.maxY + 26)
                    .allowsHitTesting(false)
            }
            tooltip()
            skipButton
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                spotlightPulse = true
            }
        }
    }

    private func tooltip(text: String, anchorId: String, proxy: GeometryProxy) -> some View {
        let rect = anchors[anchorId].map { proxy[$0] } ?? .zero
        let placeBelow = rect.midY < proxy.size.height / 2
        return VStack {
            Text(text)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(16)
                .background(Color.brandPurple, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .position(
                    x: proxy.size.width / 2,
                    y: placeBelow
                        ? min(rect.maxY + 70, proxy.size.height - 60)
                        : max(rect.minY - 70, 90)
                )
        }
        .allowsHitTesting(false)
    }

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button("スキップ") {
                    finish()
                }
                .font(.footnote.bold())
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.35), in: Capsule())
                .contentShape(Rectangle())
                .padding(.top, 60)
                .padding(.trailing, 20)
            }
            Spacer()
        }
        .allowsHitTesting(true)
        .zIndex(10)
    }

    // MARK: - ダミー候補カードでのいいね体験シミュレーション

    private func candidateSimulation(proxy: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()
            skipButton

            VStack(spacing: 18) {
                Text("最後に、気になるお相手を見つけたときの流れを体験してみましょう")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    showingFakeProfile = true
                } label: {
                    fakeCandidateCard
                }
                .buttonStyle(.plain)

                Text("↑ タップしてプロフィールを見てみましょう")
                    .font(.footnote.bold())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var fakeCandidateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                LinearGradient(colors: [Color.brandPurple.opacity(0.5), Color.brandPink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                AsyncImage(url: Self.sampleAvatarURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .frame(width: 170, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 2)
            }

            Text("サンプルさん")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text("20歳・体験用のサンプルです")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(10)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
    }

    private var fakeProfileSheet: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            ZStack {
                LinearGradient(colors: [Color.brandPurple.opacity(0.5), Color.brandPink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                AsyncImage(url: Self.sampleAvatarURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 90))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("サンプルさん・20歳")
                    .font(.title3.bold())
                Text("これは体験用のダミープロフィールです。実際のユーザーには、こんなふうにプロフィールが表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Spacer()

            // どこを押せばいいか分からない、という声があったため、
            // 実際のボタンの真上に矢印付きの案内を出して指し示す。
            if !simulatedHidden && !simulatedLiked {
                VStack(spacing: 4) {
                    Text("下の「いいねを送る」を押してみましょう")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.brandOrange, in: Capsule())
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.caption)
                        .foregroundStyle(Color.brandOrange)
                }
                .offset(y: spotlightPulse ? 4 : -4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: spotlightPulse)
                .padding(.bottom, 4)
            }

            if simulatedHidden {
                VStack(spacing: 10) {
                    Image(systemName: "eye.slash.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("非表示にしました")
                        .font(.subheadline.bold())
                    Text("実際に非表示にすると、このお相手は次から「探す」画面に表示されなくなります(いつでもマイページの「非表示リスト」から解除できます)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            } else {
                HStack(spacing: 12) {
                    Button {
                        simulatedHidden = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            showingFakeProfile = false
                            simulatedHidden = false
                            step = .myPageGuide
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "eye.slash.fill")
                            Text("非表示")
                                .font(.caption2)
                        }
                        .frame(width: 60, height: 54)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        simulatedLiked = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_100_000_000)
                            showingFakeProfile = false
                            simulatedLiked = false
                            step = .myPageGuide
                        }
                    } label: {
                        HStack {
                            Image(systemName: simulatedLiked ? "checkmark" : "hand.thumbsup.fill")
                            Text(simulatedLiked ? "送信しました!" : "いいねを送る")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(simulatedLiked ? Color.green : Color.brandPurple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .overlay {
                        if !simulatedLiked {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.brandOrange, lineWidth: 3)
                                .scaleEffect(spotlightPulse ? 1.08 : 1.0)
                                .opacity(spotlightPulse ? 0 : 1)
                                .allowsHitTesting(false)
                        }
                    }
                    .disabled(simulatedLiked)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        spotlightPulse = true
                    }
                }
            }

            if !simulatedHidden {
                Text(simulatedLiked
                     ? "いいねを送ると、自動で次のお相手が表示されます。"
                     : "※ これは練習です。実際のいいね・非表示は行われません。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
        }
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - マイページの案内

    private var myPageGuideMessage: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.brandPurple)
                Text("最後に「マイページ」もチェックしましょう")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Text("プロフィールの編集、いいねの購入、有料会員プランの確認、安心・安全ガイドなどはすべて画面右下の「マイページ」タブからアクセスできます")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 10) {
                    Button {
                        finish()
                        onGoToMyPage()
                    } label: {
                        Text("マイページを見てみる")
                            .bold()
                            .frame(width: 220, height: 50)
                            .background(Color.brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Button {
                        withAnimation { step = .closing }
                    } label: {
                        Text("あとで見る")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 締めのメッセージ

    private var closingMessage: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.brandPink)
                Text("たくさんの出会いがあることを祈っています!")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    finish()
                } label: {
                    Text("はじめる")
                        .bold()
                        .frame(width: 200, height: 50)
                        .background(Color.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
    }

    private func finish() {
        withAnimation {
            step = nil
        }
        onFinish()
    }
}

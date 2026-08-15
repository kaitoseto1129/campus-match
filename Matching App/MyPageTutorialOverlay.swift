//
//  MyPageTutorialOverlay.swift
//  Matching App
//

import SwiftUI

/// マイページを初めて開いたユーザー向けの簡易ガイド。探す画面のチュートリアルから
/// 「マイページを見てみる」で来た場合はもちろん、マイページに直接たどり着いた場合も
/// 一度だけ表示する。画面中央にカードを出すだけでなく、実際のセクションをスポットライトで
/// 指し示し、実際にタップ・操作してもらいながら趣味カード→プロフィール充実度→アピール→
/// 分析→足あと→締め、の順に紹介する。
enum MyPageTutorialStep: CaseIterable {
    case hobbyCards, completeness, appeal, analytics, footprints, closing
}

private struct StepContent {
    let anchorId: String?
    let message: String
}

struct MyPageTutorialOverlay: View {
    let step: MyPageTutorialStep
    let anchors: [String: Anchor<CGRect>]
    var onNext: () -> Void
    var onSkipAll: () -> Void

    @State private var pulse = false

    private var content: StepContent {
        switch step {
        case .hobbyCards:
            return StepContent(anchorId: "myPageHobbyCards", message: "「趣味カードを追加する」をタップして、趣味カードを登録してみましょう。共通の趣味があるお相手に見つけてもらいやすくなります")
        case .completeness:
            return StepContent(anchorId: "myPageCompleteness", message: "足りない項目は「やることリスト」でひと目で分かります。「編集する」から埋めてみましょう")
        case .appeal:
            return StepContent(anchorId: "myPageAppeal", message: "「アピールを使う」をタップすると、いいねを消費して1時間だけ「探す」画面のトップに表示されます")
        case .analytics:
            return StepContent(anchorId: "myPageAnalytics", message: "「分析」をタップすると、プロフィールの閲覧数やいいね獲得率を確認できます")
        case .footprints:
            return StepContent(anchorId: "myPageFootprints", message: "「足あと」をタップすると、あなたのプロフィールを見に来たお相手が分かります")
        case .closing:
            return StepContent(anchorId: nil, message: "")
        }
    }

    var body: some View {
        GeometryReader { proxy in
            if step == .closing {
                closingCard
            } else {
                spotlightContent(proxy: proxy)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    @ViewBuilder
    private func spotlightContent(proxy: GeometryProxy) -> some View {
        let rect = content.anchorId.flatMap { anchors[$0] }.map { proxy[$0] } ?? .zero
        ZStack {
            SpotlightScrimShape(holeRect: rect)
                .fill(Color.black.opacity(0.68), style: FillStyle(eoFill: true))
                .onTapGesture { onNext() }

            if rect != .zero {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.brandPurple, lineWidth: 3)
                    .frame(width: rect.width + 16, height: rect.height + 16)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                    .shadow(color: Color.brandPurple.opacity(0.6), radius: 10)
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.brandOrange, lineWidth: 3)
                    .frame(width: rect.width + 16, height: rect.height + 16)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .opacity(pulse ? 0 : 1)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }

            tooltip(rect: rect, proxy: proxy)
            topBar
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func tooltip(rect: CGRect, proxy: GeometryProxy) -> some View {
        let placeBelow = rect == .zero || rect.midY < proxy.size.height / 2
        return VStack(spacing: 12) {
            Text(content.message)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onNext()
            } label: {
                Text("次へ")
                    .font(.caption.bold())
                    .foregroundStyle(Color.brandPurple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
            }
        }
        .padding(16)
        .background(Color.brandPurple, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .position(
            x: proxy.size.width / 2,
            y: placeBelow
                ? min(rect.maxY + 90, proxy.size.height - 90)
                : max(rect.minY - 90, 100)
        )
    }

    private var topBar: some View {
        VStack {
            HStack {
                Spacer()
                Button("スキップ") { onSkipAll() }
                    .font(.footnote.bold())
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(.top, 60)
                    .padding(.trailing, 20)
            }
            Spacer()
        }
    }

    private var closingCard: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.brandPink)
                Text("マイページの紹介はこれで終わりです")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Text("たくさんの出会いがあることを祈っています!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    onNext()
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
}

/// 背景を暗転させつつ、対象の四角形だけくり抜いて実際のUIをそのまま操作できるようにするScrim。
/// (DiscoverTutorialOverlay.swiftの同名シェイプと同じ考え方だが、マイページのスクロール位置に
/// 応じてアンカーの矩形が変わるためこちらでも独立して持っている)
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

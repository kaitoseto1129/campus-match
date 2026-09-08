//
//  MyPageTutorialOverlay.swift
//  Matching App
//

import SwiftUI

/// マイページを初めて開いたユーザー向けの簡易ガイド。画面中央にカードを出すだけでなく、
/// 実際のセクションをスポットライトで指し示し、実際にタップ・操作してもらいながら
/// 趣味カード→プロフィール充実度→締め、の順に紹介する。
enum MyPageTutorialStep: CaseIterable {
    case hobbyCards, completeness, closing
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
            return StepContent(anchorId: "myPageHobbyCards", message: "「趣味カードを追加する」をタップして、趣味カードを登録してみましょう。集まりで話のきっかけになります")
        case .completeness:
            return StepContent(anchorId: "myPageCompleteness", message: "足りない項目は「やることリスト」でひと目で分かります。「編集する」から埋めてみましょう")
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
            // 以前は背景タップでも次へ進めるようonTapGestureを付けていたが、
            // 画面全体を覆うShapeのタップ判定が右上の「スキップ」ボタンのタップと競合し、
            // ボタンが反応しないことがあるバグの原因になっていたため削除した
            // (暗くなっている部分自体は、そのままタップを
            // 吸収して奥の実UIへ誤って伝わらないようにする役割だけを持たせる)。
            SpotlightScrimShape(holeRect: rect)
                .fill(Color.black.opacity(0.68), style: FillStyle(eoFill: true))

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
            Text(LocalizedStringKey(content.message))
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
                    .contentShape(Rectangle())
                    .padding(.top, 60)
                    .padding(.trailing, 20)
            }
            Spacer()
        }
        .allowsHitTesting(true)
        .zIndex(10)
    }

    private var closingCard: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.brandPurple)
                Text("マイページの紹介はこれで終わりです")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Text("気になる集まりに参加して、学生生活を広げてみてください!")
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
/// (マイページのスクロール位置に
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

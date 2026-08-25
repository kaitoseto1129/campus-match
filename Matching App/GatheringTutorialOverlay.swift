//
//  GatheringTutorialOverlay.swift
//  Matching App
//

import SwiftUI

enum GatheringTutorialStep: Equatable {
    case segments
    case createButton
    case closing
}

/// 背景を暗転させつつ、対象の四角形だけくり抜いて実際のUIをそのまま操作できるようにするScrim。
/// (DiscoverTutorialOverlay/MyPageTutorialOverlayにも同じ形のものがあるが、
/// private宣言のため共有できず、それぞれのファイルで個別に持っている)
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

/// 「集まり」タブを初めて開いたユーザー向けの簡易チュートリアル。
/// タブ切り替え(みんなの募集/自分が主催)→ 募集ボタン、の順に実際のUIをそのままスポットライトで案内する。
/// (探す画面のDiscoverTutorialOverlayと同じ、実UIを操作させる方式に合わせている)
struct GatheringTutorialOverlay: View {
    @Binding var step: GatheringTutorialStep?
    let anchors: [String: Anchor<CGRect>]
    var onFinish: () -> Void

    @State private var spotlightPulse = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch step {
                case .segments:
                    spotlight(id: "gatheringSegments", proxy: proxy) {
                        tooltip(
                            text: "「みんなの募集」で他の人が募集している集まりを探せます。「自分が主催」では自分が募集した・応募した集まりを確認できます。",
                            anchorId: "gatheringSegments",
                            proxy: proxy
                        )
                    }
                case .createButton:
                    spotlight(id: "gatheringCreate", proxy: proxy) {
                        tooltip(
                            text: "ここから「ご飯行きませんか」のような集まりを自分で募集できます。応募が来たら承認して、そのままグループトークができます。",
                            anchorId: "gatheringCreate",
                            proxy: proxy
                        )
                    }
                case .closing:
                    closingMessage
                case .none:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    @ViewBuilder
    private func spotlight<Content: View>(id: String, proxy: GeometryProxy, @ViewBuilder tooltip: () -> Content) -> some View {
        let rect = anchors[id].map { proxy[$0] } ?? .zero
        ZStack {
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
                    .scaleEffect(spotlightPulse ? 1.14 : 1.0)
                    .opacity(spotlightPulse ? 0 : 1)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
            tooltip()
            nextOrSkipBar(id: id)
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
            Text(LocalizedStringKey(text))
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
                        ? min(rect.maxY + 90, proxy.size.height - 100)
                        : max(rect.minY - 90, 90)
                )
        }
        .allowsHitTesting(false)
    }

    /// 実UIをそのまま操作できるスポットライト方式のため、自動では次に進まない。
    /// 「次へ」で明示的に進めるか、「スキップ」でチュートリアル自体を終えられるようにする。
    private func nextOrSkipBar(id: String) -> some View {
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
                .padding(.top, 60)
                .padding(.trailing, 20)
            }
            Spacer()
            HStack {
                Spacer()
                Button {
                    advance(from: id)
                } label: {
                    HStack(spacing: 6) {
                        Text("次へ").bold()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.brandGradient, in: Capsule())
                }
                Spacer()
            }
            .padding(.bottom, 40)
        }
        .zIndex(10)
    }

    private func advance(from id: String) {
        withAnimation {
            switch id {
            case "gatheringSegments": step = .createButton
            case "gatheringCreate": step = .closing
            default: finish()
            }
        }
    }

    private var closingMessage: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.brandPurple)
                Text("気軽にご飯や集まりに誘ってみましょう!")
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

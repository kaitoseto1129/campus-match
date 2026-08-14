//
//  MyPageTutorialOverlay.swift
//  Matching App
//

import SwiftUI

/// マイページを初めて開いたユーザー向けの簡易ガイド。探す画面のチュートリアルから
/// 「マイページを見てみる」で来た場合はもちろん、マイページに直接たどり着いた場合も
/// 一度だけ表示する。趣味カード→プロフィール充実度→アピール→分析→足あと→締め、の順に紹介する。
enum MyPageTutorialStep: Int, CaseIterable {
    case hobbyCards, completeness, appeal, analytics, footprints, closing
}

struct MyPageTutorialOverlay: View {
    @Binding var step: MyPageTutorialStep?
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            if let step {
                Group {
                    switch step {
                    case .hobbyCards:
                        card(
                            icon: "heart.text.square.fill",
                            iconColor: Color.brandPink,
                            title: "趣味カードを登録しよう",
                            message: "共通の趣味を持つお相手に見つけてもらいやすくなります。マイページ上部の「趣味カードを追加する」からいつでも登録・編集できます。"
                        )
                    case .completeness:
                        card(
                            icon: "checklist",
                            iconColor: Color.brandPurple,
                            title: "プロフィール充実度をチェック",
                            message: "足りない項目は「やることリスト」でひと目で分かります。埋めるほどお相手に見つけてもらいやすくなります。"
                        )
                    case .appeal:
                        appealCard
                    case .analytics:
                        card(
                            icon: "chart.bar.fill",
                            iconColor: .indigo,
                            title: "「分析」で振り返ろう",
                            message: "プロフィールが何回表示・いいねされたかなどを確認できます。マイページの「分析」からいつでも見られます。"
                        )
                    case .footprints:
                        card(
                            icon: "shoeprints.fill",
                            iconColor: Color.brandOrange,
                            title: "「足あと」を確認しよう",
                            message: "あなたのプロフィールを見にきたお相手が分かります。気になる人がいたら、そこからいいねを送ってみましょう。"
                        )
                    case .closing:
                        closingCard
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            skipButton
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button("スキップ") { finish() }
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

    private func card(icon: String, iconColor: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 46))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            nextButton
        }
    }

    /// アピール機能は文章だけだと伝わりにくいため、実際に「アピール中」表示になった時の
    /// プレビューを見せながら説明する。
    private var appealCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color.brandOrange)
            Text("「アピール」で目立とう")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("いいねを10消費すると、1時間だけ「探す」画面のトップに表示されて見てもらいやすくなります")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.brandOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("アピール中")
                        .font(.subheadline.bold())
                    Text("59分後に終了")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.brandOrange, lineWidth: 1.5)
            }
            .padding(.horizontal, 40)
            Text("↑ アピール中はこんな表示になります(プレビューです)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            nextButton
        }
    }

    private var closingCard: some View {
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

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            Text("次へ")
                .bold()
                .frame(width: 200, height: 50)
                .background(Color.brandGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding(.top, 8)
    }

    private func advance() {
        guard let current = step, let currentIndex = MyPageTutorialStep.allCases.firstIndex(of: current) else { return }
        let nextIndex = MyPageTutorialStep.allCases.index(after: currentIndex)
        if nextIndex < MyPageTutorialStep.allCases.endIndex {
            step = MyPageTutorialStep.allCases[nextIndex]
        } else {
            finish()
        }
    }

    private func finish() {
        step = nil
        onFinish()
    }
}

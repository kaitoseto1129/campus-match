//
//  WelcomeOnboardingView.swift
//  Matching App
//

import SwiftUI

/// アプリを初めて起動した人だけに一度だけ表示する、2ページのウェルカム画面。
/// 「はじめる」を押すとログイン/新規登録画面に進む。
struct WelcomeOnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.brandGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage(
                        icon: "person.2.fill",
                        title: "キャンパスマッチへようこそ",
                        message: "同じ大学・同じキャンパスの学生同士で\n出会える学生限定マッチングアプリです"
                    )
                    .tag(0)

                    welcomePage(
                        icon: "sparkles",
                        title: "使い方はかんたん",
                        message: "「探す」で気になる人にいいね、\nマッチしたら「トーク」でお話ししましょう"
                    )
                    .tag(1)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page == 0 {
                        withAnimation { page = 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page == 0 ? "次へ" : "はじめる")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white)
                        .foregroundStyle(Color.brandPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                if page == 0 {
                    Button("スキップ") { onFinish() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private func welcomePage(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 160, height: 160)
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    WelcomeOnboardingView { }
}

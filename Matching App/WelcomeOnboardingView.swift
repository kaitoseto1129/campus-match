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
    /// アメリカの大学生など、日本語以外での利用者がマイページに辿り着く前(登録前)から
    /// 言語を選べるようにするための切り替え。マイページの「言語」と同じ設定を共有する。
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

    var body: some View {
        ZStack {
            Color.brandGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    languageToggle
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                TabView(selection: $page) {
                    welcomePage(
                        showsAppIcon: true,
                        title: "キャンマッチへようこそ",
                        message: "キャンマッチは大学生専用の\nマッチングアプリです"
                    )
                    .tag(0)

                    welcomePage(
                        showsAppIcon: false,
                        icon: "sparkles",
                        title: "使い方はかんたん",
                        message: "「探す」で気になる人にいいね、\nマッチしたら「トーク」でお話ししましょう"
                    )
                    .tag(1)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Text("本サービスは18歳以上の大学生の方のみご利用いただけます")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)

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
                .padding(.bottom, 48)
            }
        }
    }

    private var languageToggle: some View {
        Menu {
            Picker("", selection: $appLanguageRaw) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text("言語 / Language")
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.2), in: Capsule())
        }
    }

    private func welcomePage(showsAppIcon: Bool, icon: String = "", title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            if showsAppIcon {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
            } else {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 160, height: 160)
                    Image(systemName: icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                }
            }
            Text(LocalizedStringKey(title))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(LocalizedStringKey(message))
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

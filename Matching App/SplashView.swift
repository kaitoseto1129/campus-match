//
//  SplashView.swift
//  Matching App
//

import SwiftUI

/// 起動直後のセッション確認中やプロフィール読み込み中に表示する画面。
/// 以前はProgressViewだけ、あるいは何も置いていなかったため、
/// LaunchScreenの後に「何も表示されない画面」が一瞬挟まって見えていた。
/// LaunchScreen(白背景+ロゴ)と同じ見た目にすることで、途切れずそのまま繋がって見える。
struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 28) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                ProgressView()
                    .tint(Color.brandPurple)
            }
        }
    }
}

#Preview {
    SplashView()
}

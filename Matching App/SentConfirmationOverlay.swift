//
//  SentConfirmationOverlay.swift
//  Matching App
//

import SwiftUI

/// 全画面を覆わず、プロフィール画面の上に軽く重ねて出す送信完了トースト。
struct SentConfirmationOverlay: View {
    var message: String = "いいねを送りました"
    var icon: String = "hand.thumbsup.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandPurple)
            Text(message)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

extension View {
    /// 送信確認トーストを画面中央に、背景を暗転させずに表示する。
    /// (小さいカードの中にoverlayで出すと親のクリップ範囲で隠れてしまうことがあるため、
    /// 透明背景のfullScreenCoverで確実に画面全体の中央に出す)
    func sentConfirmationCover(isPresented: Binding<Bool>, message: String, icon: String) -> some View {
        self.fullScreenCover(isPresented: isPresented) {
            SentConfirmationOverlay(message: message, icon: icon)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .presentationBackground(.clear)
        }
    }
}

#Preview {
    SentConfirmationOverlay()
}

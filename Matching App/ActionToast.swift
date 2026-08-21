//
//  ActionToast.swift
//  Matching App
//

import SwiftUI

/// 非表示・ブロック・通報など、結果が画面上ではっきり分かりにくい操作の後に
/// 一瞬だけ表示する完了メッセージ。以前は成功しても何も表示されず、
/// 「ボタンが反応していない」ように見えてしまっていた。
struct ActionToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(LocalizedStringKey(message))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.82), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { self.message = nil }
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

extension View {
    /// messageがnilでなくなると、画面上部にトーストで一瞬表示して自動的に消える。
    func actionToast(_ message: Binding<String?>) -> some View {
        modifier(ActionToastModifier(message: message))
    }
}

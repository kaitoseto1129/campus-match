//
//  TutorialAnchor.swift
//  Matching App
//

import SwiftUI

/// 初回チュートリアルでハイライトしたい要素の位置を集めるためのPreferenceKey。
/// 集まり画面・マイページのチュートリアルオーバーレイが共通で使う。
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

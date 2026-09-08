//
//  PrivacyToggleRows.swift
//  Matching App
//

import SwiftUI

/// マイページの設定欄のプライバシー関連トグル。
/// 以前は「いいね数表示」「プライベートモード」も並べていたが、
/// 1対1のいいね機能・有料会員と一緒に廃止した。
struct PrivacyToggleRows: View {
    @ObservedObject var profileManager: ProfileManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: Binding(
                get: { profileManager.profile?.showOnlineStatus ?? true },
                set: { newValue in
                    Task { await profileManager.updateShowOnlineStatus(newValue) }
                }
            )) {
                Text("オンライン状態を表示する")
                    .font(.subheadline)
            }
            .tint(Color.brandPurple)
            Text("OFFにすると他ユーザーからオンライン/オフラインが見えなくなります")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

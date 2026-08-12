//
//  NotificationPermissionView.swift
//  Matching App
//

import SwiftUI
import UserNotifications

/// プロフィール完成後、初回だけ表示するプッシュ通知の許可案内画面。
/// 「有効にする」を押すとOS標準の許可ダイアログが出る。
struct NotificationPermissionView: View {
    var onFinish: () -> Void
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            Color.appListBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.brandPurple.opacity(0.15))
                        .frame(width: 160, height: 160)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.brandPurple)
                }
                Text("通知を有効にしよう")
                    .font(.title2.bold())
                Text("いいねやマッチ、メッセージが届いた時に\nすぐに気付けるようになります")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Spacer()

                Button {
                    Task {
                        isRequesting = true
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .badge, .sound])
                        isRequesting = false
                        onFinish()
                    }
                } label: {
                    Text("通知を有効にする")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.brandPurple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .disabled(isRequesting)
                .padding(.horizontal, 32)

                Button("あとで設定する") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
                    .disabled(isRequesting)
            }
        }
    }
}

#Preview {
    NotificationPermissionView { }
}

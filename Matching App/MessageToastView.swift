//
//  MessageToastView.swift
//  Matching App
//

import SwiftUI

struct MessageToastView: View {
    let toast: MessageToast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "message.fill")
                .foregroundStyle(Color.brandRed)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.senderName)
                    .font(.subheadline.bold())
                if !toast.preview.isEmpty {
                    Text(toast.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 6)
        .padding(.horizontal)
        .onTapGesture { onDismiss() }
    }
}

#Preview {
    MessageToastView(toast: MessageToast(id: UUID(), matchId: UUID(), senderName: "佐藤 美咲", preview: "こんにちは!")) {}
}

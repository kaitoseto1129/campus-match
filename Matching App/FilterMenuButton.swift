//
//  FilterMenuButton.swift
//  Matching App
//

import SwiftUI

/// 絞り込みボタン。常時表示し、絞り込み中かどうかで見た目と文言が切り替わる。
struct FilterMenuButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "slider.horizontal.3")
                Text(isActive ? "絞り込み中" : "絞り込み")
            }
            .font(.subheadline.bold())
            .foregroundStyle(isActive ? Color.brandRed : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isActive ? Color.brandRed.opacity(0.12) : Color(.systemGray6), in: Capsule())
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        FilterMenuButton(isActive: false) {}
        FilterMenuButton(isActive: true) {}
    }
}

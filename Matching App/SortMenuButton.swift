//
//  SortMenuButton.swift
//  Matching App
//

import SwiftUI

/// 並び替えの現在状態を示すボタン。「ログイン順」「おすすめ順」を切り替えられる。
struct SortMenuButton: View {
    @Binding var sortOrder: DiscoverSortOrder

    private var label: String {
        switch sortOrder {
        case .lastActive: return "ログイン順"
        case .recommended: return "おすすめ順"
        }
    }

    var body: some View {
        Menu {
            Button {
                sortOrder = .lastActive
            } label: {
                if sortOrder == .lastActive {
                    Label("ログイン順", systemImage: "checkmark")
                } else {
                    Text("ログイン順")
                }
            }
            Button {
                sortOrder = .recommended
            } label: {
                if sortOrder == .recommended {
                    Label("おすすめ順", systemImage: "checkmark")
                } else {
                    Text("おすすめ順")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    SortMenuButton(sortOrder: .constant(.lastActive))
}

//
//  SafetyGuideView.swift
//  Matching App
//

import SwiftUI

private struct GuideItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

private let guideItems: [GuideItem] = [
    GuideItem(icon: "lock.fill", title: "個人情報を守る", body: "電話番号や住所などの個人情報は、信頼できる相手だと確認できるまで教えないようにしましょう。"),
    GuideItem(icon: "person.crop.circle.badge.exclamationmark", title: "不審なユーザーを報告", body: "不快な言動をするユーザーを見つけたら、ブロック・報告機能をご利用ください。"),
    GuideItem(icon: "cup.and.saucer.fill", title: "初めて会うときは", body: "初対面は人目のある場所で、日中に会うことをおすすめします。"),
    GuideItem(icon: "creditcard.trianglebadge.exclamationmark", title: "金銭のやり取りに注意", body: "マッチした相手からの金銭要求には応じず、運営までご連絡ください。"),
]

struct SafetyGuideView: View {
    var body: some View {
        List(guideItems) { item in
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(Color.brandBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .listStyle(.plain)
        .navigationTitle("安心・安全ガイド")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SafetyGuideView()
    }
}

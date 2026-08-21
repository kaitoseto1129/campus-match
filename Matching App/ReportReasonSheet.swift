//
//  ReportReasonSheet.swift
//  Matching App
//

import SwiftUI

/// 違反報告の理由を選択肢から選ばせるシート。以前はチェックする理由文言が固定だったが、
/// ユーザー自身に理由を選んでもらえるようにする。
struct ReportReasonSheet: View {
    let targetName: String
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    static let reasons: [(icon: String, text: String)] = [
        ("envelope.badge.fill", "スパム・勧誘"),
        ("person.fill.questionmark", "なりすまし・虚偽プロフィール"),
        ("photo.fill.on.rectangle.fill", "不適切な写真"),
        ("exclamationmark.bubble.fill", "誹謗中傷・迷惑行為"),
        ("person.crop.circle.badge.exclamationmark", "未成年の疑い"),
        ("ellipsis.circle.fill", "その他")
    ]

    var body: some View {
        NavigationStack {
            List(Self.reasons, id: \.text) { reason in
                Button {
                    onSubmit(reason.text)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: reason.icon)
                            .font(.body)
                            .foregroundStyle(Color.brandPurple)
                            .frame(width: 24)
                        Text(LocalizedStringKey(reason.text)).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color(.systemBackground))
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(targetName)さんを報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.thickMaterial)
    }
}

#Preview {
    ReportReasonSheet(targetName: "サンプル") { _ in }
}

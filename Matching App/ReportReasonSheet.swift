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

    static let reasons = [
        "スパム・勧誘", "なりすまし・虚偽プロフィール", "不適切な写真",
        "誹謗中傷・迷惑行為", "未成年の疑い", "その他"
    ]

    var body: some View {
        NavigationStack {
            List(Self.reasons, id: \.self) { reason in
                Button {
                    onSubmit(reason)
                    dismiss()
                } label: {
                    HStack {
                        Text(reason).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(targetName)さんを報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ReportReasonSheet(targetName: "サンプル") { _ in }
}

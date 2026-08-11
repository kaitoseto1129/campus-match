//
//  AIBioComposerView.swift
//  Matching App
//

import SwiftUI

/// 自己紹介を全部手書きさせると離脱率が上がるため、
/// 「仕事」「趣味」「好きな食べ物」を選択式で選ぶだけで自己紹介文の下書きを自動生成する画面。
/// 生成後もテキストは自由に編集できる。
struct AIBioComposerView: View {
    var onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedJob: String? = nil
    @State private var selectedHobbies: Set<String> = []
    @State private var selectedFoods: Set<String> = []
    @State private var generatedText: String = ""
    @State private var showingResult = false

    private let jobOptions = ["サラリーマン", "大学生", "大学院生", "公務員", "自営業", "医療従事者", "エンジニア", "クリエイター"]
    private let hobbyOptions = ["カフェ巡り", "映画鑑賞", "旅行", "筋トレ", "読書", "音楽鑑賞", "料理", "ドライブ", "アウトドア", "ゲーム", "写真撮影", "ショッピング"]
    private let foodOptions = ["ラーメン", "お寿司", "焼肉", "イタリアン", "カフェ・スイーツ", "和食", "韓国料理", "中華料理"]

    var body: some View {
        NavigationStack {
            Form {
                if showingResult {
                    Section("生成結果(自由に編集できます)") {
                        TextField("自己紹介", text: $generatedText, axis: .vertical)
                            .lineLimit(8...16)
                    }
                } else {
                    Section("お仕事・身分(1つ選択)") {
                        chipGrid(options: jobOptions, isSelected: { $0 == selectedJob }) { option in
                            selectedJob = (selectedJob == option) ? nil : option
                        }
                    }
                    Section("趣味(複数選択可)") {
                        chipGrid(options: hobbyOptions, isSelected: { selectedHobbies.contains($0) }) { option in
                            toggle(option, in: &selectedHobbies)
                        }
                    }
                    Section("好きな食べ物(複数選択可)") {
                        chipGrid(options: foodOptions, isSelected: { selectedFoods.contains($0) }) { option in
                            toggle(option, in: &selectedFoods)
                        }
                    }
                }
            }
            .navigationTitle("AIで自己紹介を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                if showingResult {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("この内容を使う") { onComplete(generatedText) }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("生成する") {
                            generatedText = Self.compose(job: selectedJob, hobbies: Array(selectedHobbies), foods: Array(selectedFoods))
                            showingResult = true
                        }
                        .disabled(selectedJob == nil && selectedHobbies.isEmpty && selectedFoods.isEmpty)
                    }
                }
            }
        }
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func chipGrid(options: [String], isSelected: @escaping (String) -> Bool, action: @escaping (String) -> Void) -> some View {
        FlowLayoutView(options: options) { option in
            let selected = isSelected(option)
            Button {
                action(option)
            } label: {
                Text(option)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selected ? Color.brandBlue : Color(.systemGray6), in: Capsule())
                    .foregroundStyle(selected ? .white : .primary)
            }
            .buttonStyle(.plain)
        }
    }

    /// 選択されたタグから、簡単な文章テンプレートを組み合わせて自己紹介の下書きを作る。
    static func compose(job: String?, hobbies: [String], foods: [String]) -> String {
        var lines: [String] = []
        if let job {
            lines.append("【仕事】\n\(job)をしています。")
        }
        if !hobbies.isEmpty {
            lines.append("【趣味】\n\(hobbies.joined(separator: "・"))が好きです。休みの日はよく楽しんでいます。")
        }
        if !foods.isEmpty {
            lines.append("【好きな食べ物】\n\(foods.joined(separator: "・"))が好きです。おすすめのお店があったら教えてください!")
        }
        lines.append("よろしくお願いします!")
        return lines.joined(separator: "\n\n")
    }
}

/// チップ(タグ)を折り返しながら並べる簡易フローレイアウト。
struct FlowLayoutView<Content: View>: View {
    let options: [String]
    @ViewBuilder var content: (String) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                content(option)
            }
        }
    }
}

/// iOS 16+のLayoutプロトコルを使った折り返しレイアウト。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? currentX : maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.minX + maxWidth, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    AIBioComposerView { _ in }
}

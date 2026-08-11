//
//  RibbonBadge.swift
//  Matching App
//

import SwiftUI

private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width - notch, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// with風の左上フラグ・リボン型バッジ(「今週入会」等)
struct RibbonBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .background(color, in: RibbonShape())
    }
}

#Preview {
    RibbonBadge(text: "今週入会", color: .brandBlue)
        .padding()
}

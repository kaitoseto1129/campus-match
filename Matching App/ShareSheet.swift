//
//  ShareSheet.swift
//  Matching App
//

import SwiftUI
import UIKit

/// 共有が「実際に完了したか」を受け取れる共有シート。
///
/// SwiftUIのShareLinkは完了を知る手段がないため、共有シートを開いただけで
/// 紹介ボーナスを付与してしまい、キャンセルしてもいいねがもらえる状態になっていた。
/// UIActivityViewControllerのcompletionWithItemsHandlerを使い、
/// 実際に共有先が選ばれて完了した時だけtrueを返す。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    /// 共有が完了したらtrue、キャンセルされたらfalse。
    var onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

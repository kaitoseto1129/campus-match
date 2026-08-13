//
//  LegalLinks.swift
//  Matching App
//

import Foundation

/// 利用規約・プライバシーポリシー・サポートページのURL。
///
/// これらはApp Storeの審査でReviewerが実際に開くため、
/// 認証なしで誰でも閲覧できる公開URLである必要がある
/// (以前はClaudeのartifactのURLを指しており、Reviewerからは開けない状態だった)。
/// 実体はこのリポジトリの docs/ 配下にあり、GitHub Pagesで公開している。
enum LegalLinks {
    private static let base = "https://kaitoseto1129.github.io/campus-match"

    static let terms = URL(string: "\(base)/terms.html")!
    static let privacy = URL(string: "\(base)/privacy.html")!
    static let support = URL(string: "\(base)/")!
}

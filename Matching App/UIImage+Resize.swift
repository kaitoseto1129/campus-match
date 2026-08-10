//
//  UIImage+Resize.swift
//  Matching App
//

import UIKit

extension UIImage {
    /// アップロード前の軽量化用。長辺が指定サイズを超える場合のみ縮小する(小さい画像はそのまま)。
    func resized(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

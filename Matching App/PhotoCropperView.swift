//
//  PhotoCropperView.swift
//  Matching App
//

import SwiftUI

/// UIImageはEquatable/Identifiableではないため、.fullScreenCover(item:)に渡すためのラッパー。
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 写真選択直後に表示する、正方形トリミング画面。
/// ピンチ・ドラッグで表示範囲を調整し、「使用する」を押すとその範囲だけを切り出したUIImageを返す。
/// 顔検出はこのトリミング後の画像に対して行われる。
struct PhotoCropperView: View {
    let image: UIImage
    let onComplete: (UIImage?) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = UIScreen.main.bounds.width - 40

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cropSize, height: cropSize)
                            .scaleEffect(scale)
                            .offset(offset)
                            .clipShape(Rectangle())
                    }
                    .frame(width: cropSize, height: cropSize)
                    .clipped()
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                },
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    Text("ピンチで拡大縮小、ドラッグで位置調整できます")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button {
                        onComplete(renderCroppedImage())
                    } label: {
                        Text("この範囲を使用する")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.brandBlue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("写真を調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onComplete(nil) }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    /// 画面上でユーザーが調整した表示範囲(cropSize四方の正方形)を、元画像の解像度でレンダリングし直す。
    /// UIImage.draw(in:)を使うことでimageOrientationの向き補正をUIKitに任せ、素のCGImageクロップで
    /// 起きがちな向きズレを避けている。
    private func renderCroppedImage() -> UIImage {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return image }

        // scaledToFillでcropSizeいっぱいに表示するための基準スケール。
        let baseScale = max(cropSize / imageSize.width, cropSize / imageSize.height)
        let totalScale = baseScale * scale

        let displayedWidth = imageSize.width * totalScale
        let displayedHeight = imageSize.height * totalScale

        // クロップ枠(cropSize四方、画面中央)が、スケール後画像のどの矩形に対応するかを求める。
        let cropOriginX = (displayedWidth - cropSize) / 2 - offset.width
        let cropOriginY = (displayedHeight - cropSize) / 2 - offset.height

        let renderScale = image.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = renderScale
            format.opaque = true
            return format
        }())
        return renderer.image { _ in
            image.draw(in: CGRect(x: -cropOriginX, y: -cropOriginY, width: displayedWidth, height: displayedHeight))
        }
    }
}

#Preview {
    PhotoCropperView(image: UIImage(systemName: "person.fill") ?? UIImage()) { _ in }
}

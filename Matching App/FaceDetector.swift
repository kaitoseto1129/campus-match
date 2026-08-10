//
//  FaceDetector.swift
//  Matching App
//

import CoreImage
import UIKit

enum FaceCheckResult {
    case ok
    case noFace
    case tooSmall
    case multipleFaces

    var message: String? {
        switch self {
        case .ok:
            return nil
        case .noFace:
            return "顔が写っている写真を選んでください"
        case .tooSmall:
            return "顔が小さすぎます。もっと大きく写ってる写真を選んでください"
        case .multipleFaces:
            return "複数人が写っています。あなた一人の写真を選んでください"
        }
    }
}

struct FaceDetector {
    func checkFace(image: UIImage) async -> FaceCheckResult {
        guard let ciImage = CIImage(image: image) else {
            return .noFace
        }

        let orientation = image.imageOrientation.exifOrientation

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let detector = CIDetector(
                    ofType: CIDetectorTypeFace,
                    context: CIContext(),
                    options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
                )

                let faces = detector?.features(
                    in: ciImage,
                    options: [CIDetectorImageOrientation: orientation]
                ) ?? []

                guard !faces.isEmpty else {
                    continuation.resume(returning: .noFace)
                    return
                }

                guard faces.count == 1 else {
                    continuation.resume(returning: .multipleFaces)
                    return
                }

                let imageArea = ciImage.extent.width * ciImage.extent.height
                let faceArea = faces[0].bounds.width * faces[0].bounds.height

                guard imageArea > 0, faceArea / imageArea >= 0.03 else {
                    continuation.resume(returning: .tooSmall)
                    return
                }

                continuation.resume(returning: .ok)
            }
        }
    }
}

private extension UIImage.Orientation {
    var exifOrientation: Int {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}

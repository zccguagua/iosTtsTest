import UIKit
import Vision

enum OcrError: LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "图片无法读取"
        case .recognitionFailed: return "识别失败，请重试"
        }
    }
}

/// 用 Vision 做离线文字识别，对应 Android 端的 ML Kit 中文识别。
///
/// Vision 的中文识别模型随系统提供：不用打包进 App、不用联网、不占安装包体积。
enum TextRecognizer {

    static func recognizeText(in image: UIImage) async throws -> String {
        // 原图动辄 4000px，先缩到 2048 长边，识别更快、准确率基本不变
        let prepared = image.downscaled(maxDimension: 2048)
        guard let cgImage = prepared.cgImage else { throw OcrError.invalidImage }

        let orientation = CGImagePropertyOrientation(prepared.imageOrientation)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let guardFlag = ResumeGuard()

            request.completionHandler = { finishedRequest, error in
                guard guardFlag.claim() else { return }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                // VNRequest.results 是 [VNObservation]，这里要转成文字观察结果
                let observations = (finishedRequest.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: orientation,
                        options: [:]
                    )
                    try handler.perform([request])
                } catch {
                    if guardFlag.claim() {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

/// 保证 continuation 只被 resume 一次：Vision 的 completionHandler 和 perform 的 throw
/// 可能同时发生，重复 resume 会直接崩溃。
private final class ResumeGuard {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

private extension UIImage {
    /// 等比缩小到长边不超过 maxDimension，同时把 EXIF 方向烘焙进像素里
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

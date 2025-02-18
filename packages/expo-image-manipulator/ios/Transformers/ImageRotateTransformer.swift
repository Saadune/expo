// Copyright 2024-present 650 Industries. All rights reserved.

/**
 Transformer that creates a new image by rotating given image by the rotate angle.
 */
internal struct ImageRotateTransformer: ImageTransformer {
  let rotate: Double

  @MainActor
  func transform(image: UIImage) async throws -> UIImage {
    guard let cgImage = image.cgImage else {
      throw ImageNotFoundException()
    }
    let rads = rotate * Double.pi / 180
    let rotatedView = UIView(frame: CGRect(origin: .zero, size: image.size))

    rotatedView.transform = CGAffineTransform(rotationAngle: rads)

    let rotatedSize = CGSize(width: rotatedView.frame.size.width.rounded(.down), height: rotatedView.frame.size.height.rounded(.down))
    let origin = CGPoint(x: -image.size.width / 2, y: -image.size.height / 2)

    return try drawInNewContext(size: rotatedSize) { context in
      context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
      context.rotate(by: rads)
      context.scaleBy(x: 1.0, y: -1.0)
      context.draw(cgImage, in: CGRect(origin: origin, size: image.size))
    }
  }
}

/*
  Copyright (c) 2017-2021 M.I. Hollemans

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
*/

#if canImport(UIKit)

import UIKit
import CoreML

// Don't forget to add to the project:
// 1. DeepLabV3 - https://developer.apple.com/machine-learning/models/
// 2. CoreMLHelpers - https://github.com/hollance/CoreMLHelpers

enum RemoveBackroundResult {
    case background
    case finalImage
}

extension UIImage {
    
//    func removeBackground(returnResult: RemoveBackroundResult) -> UIImage? {
//        guard let model = getDeepLabV3Model() else { return nil }
//        let width: CGFloat = 513
//        let height: CGFloat = 513
//        let resizedImage = resized(to: CGSize(width: height, height: height), scale: 1)
//        guard let pixelBuffer = resizedImage.pixelBuffer(width: Int(width), height: Int(height)),
//              let outputPredictionImage = try? model.prediction(image: pixelBuffer),
//              let outputImage = outputPredictionImage.semanticPredictions.image(min: 0, max: 1, axes: (0, 0, 1)),
//              let outputCIImage = CIImage(image: outputImage),
//              let maskImage = outputCIImage.removeWhitePixels(),
//              let maskBlurImage = maskImage.applyBlurEffect() else { return nil }
//
//        switch returnResult {
//            case .finalImage:
//                guard let resizedCIImage = CIImage(image: resizedImage),
//                      let compositedImage = resizedCIImage.composite(with: maskBlurImage) else { return nil }
//                let finalImage = UIImage(ciImage: compositedImage)
//                    .resized(to: CGSize(width: size.width, height: size.height))
//                return finalImage
//            case .background:
//                let finalImage = UIImage(
//                    ciImage: maskBlurImage,
//                    scale: scale,
//                    orientation: self.imageOrientation
//                ).resized(to: CGSize(width: size.width, height: size.height))
//                return finalImage
//        }
//    }
//
//    private func getDeepLabV3Model() -> DeepLabV3? {
//        do {
//            let config = MLModelConfiguration()
//            return try DeepLabV3(configuration: config)
//        } catch {
//            print("Error loading model: \(error)")
//            return nil
//        }
//    }
    
}

extension CIImage {
    
    func removeWhitePixels() -> CIImage? {
        let chromaCIFilter = chromaKeyFilter()
        chromaCIFilter?.setValue(self, forKey: kCIInputImageKey)
        return chromaCIFilter?.outputImage
    }
    
    func composite(with mask: CIImage) -> CIImage? {
        return CIFilter(
            name: "CISourceOutCompositing",
            parameters: [
                kCIInputImageKey: self,
                kCIInputBackgroundImageKey: mask
            ]
        )?.outputImage
    }
    
    func applyBlurEffect() -> CIImage? {
        let context = CIContext(options: nil)
        let clampFilter = CIFilter(name: "CIAffineClamp")!
        clampFilter.setDefaults()
        clampFilter.setValue(self, forKey: kCIInputImageKey)
        
        guard let currentFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        currentFilter.setValue(clampFilter.outputImage, forKey: kCIInputImageKey)
        currentFilter.setValue(2, forKey: "inputRadius")
        guard let output = currentFilter.outputImage,
              let cgimg = context.createCGImage(output, from: extent) else { return nil }
        
        return CIImage(cgImage: cgimg)
    }
    
        // modified from https://developer.apple.com/documentation/coreimage/applying_a_chroma_key_effect
    private func chromaKeyFilter() -> CIFilter? {
        let size = 64
        var cubeRGB = [Float]()
        
        for z in 0 ..< size {
            let blue = CGFloat(z) / CGFloat(size - 1)
            for y in 0 ..< size {
                let green = CGFloat(y) / CGFloat(size - 1)
                for x in 0 ..< size {
                    let red = CGFloat(x) / CGFloat(size - 1)
                    let brightness = getBrightness(red: red, green: green, blue: blue)
                    let alpha: CGFloat = brightness == 1 ? 0 : 1
                    cubeRGB.append(Float(red * alpha))
                    cubeRGB.append(Float(green * alpha))
                    cubeRGB.append(Float(blue * alpha))
                    cubeRGB.append(Float(alpha))
                }
            }
        }
        
        var data = Data()
        cubeRGB.withUnsafeBufferPointer() { ptr in
            data = Data(buffer: ptr)
        }
        
        let colorCubeFilter = CIFilter(
            name: "CIColorCube",
            parameters: [
                "inputCubeDimension": size,
                "inputCubeData": data
            ]
        )
        return colorCubeFilter
    }
    
        // modified from https://developer.apple.com/documentation/coreimage/applying_a_chroma_key_effect
    private func getBrightness(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var brightness: CGFloat = 0
        color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness
    }
    
}

extension UIImage {
  /**
    Resizes the image.

    - Parameter scale: If this is 1, `newSize` is the size in pixels.
  */
  @nonobjc public func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let image = renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
    return image
  }

  /**
    Rotates the image around its center.

    - Parameter degrees: Rotation angle in degrees.
    - Parameter keepSize: If true, the new image has the size of the original
      image, so portions may be cropped off. If false, the new image expands
      to fit all the pixels.
  */
  @nonobjc public func rotated(by degrees: CGFloat, keepSize: Bool = true) -> UIImage {
    let radians = degrees * .pi / 180
    let newRect = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians))

    // Trim off the extremely small float value to prevent Core Graphics from rounding it up.
    var newSize = keepSize ? size : newRect.size
    newSize.width = floor(newSize.width)
    newSize.height = floor(newSize.height)

    return UIGraphicsImageRenderer(size: newSize).image { rendererContext in
      let context = rendererContext.cgContext
      context.setFillColor(UIColor.black.cgColor)
      context.fill(CGRect(origin: .zero, size: newSize))
      context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
      context.rotate(by: radians)
      let origin = CGPoint(x: -size.width / 2, y: -size.height / 2)
      draw(in: CGRect(origin: origin, size: size))
    }
  }
}

#endif

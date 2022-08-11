//
//  CVPixelBuffer.swift
//  ObjectTrackingConsole
//
//  Created by Peter Linder on 8/1/22.
//

import CoreImage
import UniformTypeIdentifiers

// https://stackoverflow.com/questions/53132611/copy-a-cvpixelbuffer-on-any-ios-device
enum PixelBufferCopyError : Error {
	case allocationFailed
}

public extension CVPixelBuffer {
	func copy() -> CVPixelBuffer? {
		precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")

		var _copy: CVPixelBuffer?

		let width = CVPixelBufferGetWidth(self)
		let height = CVPixelBufferGetHeight(self)
		let formatType = CVPixelBufferGetPixelFormatType(self)
		let attachments = CVBufferCopyAttachments(self, .shouldPropagate)

		CVPixelBufferCreate(nil, width, height, formatType, attachments, &_copy)

		guard let copy = _copy else {
			return nil
		}

		CVPixelBufferLockBaseAddress(self, .readOnly)
		CVPixelBufferLockBaseAddress(copy, [])

		defer {
			CVPixelBufferUnlockBaseAddress(copy, [])
			CVPixelBufferUnlockBaseAddress(self, .readOnly)
		}

		let pixelBufferPlaneCount: Int = CVPixelBufferGetPlaneCount(self)


		if pixelBufferPlaneCount == 0 {
			let dest = CVPixelBufferGetBaseAddress(copy)
			let source = CVPixelBufferGetBaseAddress(self)
			let height = CVPixelBufferGetHeight(self)
			let bytesPerRowSrc = CVPixelBufferGetBytesPerRow(self)
			let bytesPerRowDest = CVPixelBufferGetBytesPerRow(copy)
			if bytesPerRowSrc == bytesPerRowDest {
				memcpy(dest, source, height * bytesPerRowSrc)
			} else {
				var startOfRowSrc = source
				var startOfRowDest = dest
				for _ in 0..<height {
					memcpy(startOfRowDest, startOfRowSrc, min(bytesPerRowSrc, bytesPerRowDest))
					startOfRowSrc = startOfRowSrc?.advanced(by: bytesPerRowSrc)
					startOfRowDest = startOfRowDest?.advanced(by: bytesPerRowDest)
				}
			}

		} else {
			for plane in 0 ..< pixelBufferPlaneCount {
				let dest        = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
				let source      = CVPixelBufferGetBaseAddressOfPlane(self, plane)
				let height      = CVPixelBufferGetHeightOfPlane(self, plane)
				let bytesPerRowSrc = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
				let bytesPerRowDest = CVPixelBufferGetBytesPerRowOfPlane(copy, plane)

				if bytesPerRowSrc == bytesPerRowDest {
					memcpy(dest, source, height * bytesPerRowSrc)
				} else {
					var startOfRowSrc = source
					var startOfRowDest = dest
					for _ in 0..<height {
						memcpy(startOfRowDest, startOfRowSrc, min(bytesPerRowSrc, bytesPerRowDest))
						startOfRowSrc = startOfRowSrc?.advanced(by: bytesPerRowSrc)
						startOfRowDest = startOfRowDest?.advanced(by: bytesPerRowDest)
					}
				}
			}
		}
		return copy
	}
	
	func toCGImage() -> CGImage? {
		let ciImage = CIImage(cvPixelBuffer: self)
		let context = CIContext()
		let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
		return cgImage
	}
}

public extension CGImage {
	func createPixelBuffer() -> CVPixelBuffer? {
		let image = CIImage(cgImage: self)
		
		let attrs = [
		  kCVPixelBufferCGImageCompatibilityKey: false,
		  kCVPixelBufferCGBitmapContextCompatibilityKey: false,
		  kCVPixelBufferWidthKey: Int(image.extent.width),
		  kCVPixelBufferHeightKey: Int(image.extent.height)
		] as CFDictionary
		var pixelBuffer : CVPixelBuffer?
		let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
	  
		guard (status == kCVReturnSuccess) else {
		  return nil
		}
	  
		let context = CIContext()
		context.render(image, to: pixelBuffer!)
		return pixelBuffer
	}
	
	func createCGContext() -> CGContext? {
		let dataProvider = self.dataProvider!
		let data = dataProvider.data!
		let length = CFDataGetLength(data)
		let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
		CFDataGetBytes(data, CFRange(location: 0, length: length), bytes)
		let ctx = CGContext(
			data: bytes,
			width: self.width,
			height: self.height,
			bitsPerComponent: self.bitsPerComponent,
			bytesPerRow: self.bytesPerRow,
			space: self.colorSpace!,
			bitmapInfo: self.bitmapInfo.rawValue
		)
		return ctx
	}
	
	@discardableResult func saveImage(url: URL) -> Bool {
		guard
			let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)
		else {
			return false
		}
		CGImageDestinationAddImage(destination, self, nil)
		return CGImageDestinationFinalize(destination)
	}
}

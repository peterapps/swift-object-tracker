//
//  VideoReader.swift
//  ObjectTrackingConsole
//
//  Created by Peter Linder on 8/1/22.
//

import AVKit

internal class VideoReader {
	var frameRate: Float32 {
		return self.videoTrack.nominalFrameRate
	}
	
	var numFrames: Int {
		let numSecs = CMTimeGetSeconds(videoAsset!.duration)
		let numFrames = Float(numSecs) * frameRate
		return Int(ceil(numFrames))
	}
	
	var size: CGSize {
		let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
		return CGSize(width: abs(size.width), height: abs(size.height))
	}

	var affineTransform: CGAffineTransform {
		return self.videoTrack.preferredTransform.inverted()
	}
	
	var orientation: CGImagePropertyOrientation {
		let angleInDegrees = atan2(self.affineTransform.b, self.affineTransform.a) * CGFloat(180) / CGFloat.pi
		
		var orientation: UInt32 = 1
		switch angleInDegrees {
		case 0:
			orientation = 1 // Recording button is on the right
		case 180:
			orientation = 3 // abs(180) degree rotation recording button is on the right
		case -180:
			orientation = 3 // abs(180) degree rotation recording button is on the right
		case 90:
			orientation = 8 // 90 degree CW rotation recording button is on the top
		case -90:
			orientation = 6 // 90 degree CCW rotation recording button is on the bottom
		default:
			orientation = 1
		}
		
		return CGImagePropertyOrientation(rawValue: orientation)!
	}
	
	private var videoAsset: AVAsset!
	private var videoTrack: AVAssetTrack!
	private var assetReader: AVAssetReader!
	private var videoAssetReaderOutput: AVAssetReaderTrackOutput!

	init?(videoAsset: AVAsset) {
		self.videoAsset = videoAsset
		self.videoTrack = self.videoAsset.tracks(withMediaType: AVMediaType.video)[0]

		guard self.restart() else {
			return nil
		}
	}

	func restart() -> Bool {
		do {
			self.assetReader = try AVAssetReader(asset: videoAsset)
		} catch {
			print("Failed to create AVAssetReader object: \(error)")
			return false
		}
		
		self.videoAssetReaderOutput = AVAssetReaderTrackOutput(track: self.videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
		guard self.videoAssetReaderOutput != nil else {
			return false
		}
		
		self.videoAssetReaderOutput.alwaysCopiesSampleData = true

		guard self.assetReader.canAdd(videoAssetReaderOutput) else {
			return false
		}
		
		self.assetReader.add(videoAssetReaderOutput)
		
		return self.assetReader.startReading()
	}

	func nextFrame() -> CVPixelBuffer? {
		guard let sampleBuffer = self.videoAssetReaderOutput.copyNextSampleBuffer() else {
			return nil
		}
		
		return CMSampleBufferGetImageBuffer(sampleBuffer)
	}
}

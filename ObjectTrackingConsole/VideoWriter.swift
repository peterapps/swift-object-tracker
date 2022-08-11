//
//  VideoWriter.swift
//  ObjectTrackingConsole
//
//  Created by Peter Linder on 8/1/22.
//

import AVKit

internal class VideoWriter {
	private var assetWriter: AVAssetWriter
	private var assetWriterInput: AVAssetWriterInput
	private var assetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor
	private var frameCount: Int
	private var frameRate: Int
	
	init(url: URL, fileType: AVFileType, frameRate: Int, settings: [String : Any]){
		self.assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
		
		self.assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(
			assetWriterInput: assetWriterInput,
			sourcePixelBufferAttributes: nil
		)
		
		self.assetWriter = try! AVAssetWriter(outputURL: url, fileType: fileType)
		self.assetWriter.add(assetWriterInput)
		self.assetWriter.startWriting()
		self.assetWriter.startSession(atSourceTime: CMTime.zero)
		
		self.frameCount = 0
		self.frameRate = frameRate
	}
	
	@discardableResult func writeFrame(pixelBuffer: CVPixelBuffer) -> Bool {
		let frameTime = CMTimeMake(value: Int64(self.frameCount), timescale: Int32(self.frameRate))
		self.frameCount += 1
		return self.assetWriterAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
	}
	
	func closeAsync() async {
		self.assetWriterInput.markAsFinished()
		await self.assetWriter.finishWriting()
	}
	
	func closeSync() {
		let semaphore = DispatchSemaphore(value: 0)
		
		Task {
			await self.closeAsync()
			semaphore.signal()
		}
		
		semaphore.wait()
	}
}

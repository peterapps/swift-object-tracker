//
//  main.swift
//  ObjectTrackingConsole
//
//  Created by Peter Linder on 8/1/22.
//

import Foundation
import AVKit
import Vision
import CoreImage

print("Hello, World!")

// Load video
let inputPath = URL(fileURLWithPath: "/Users/peter/Downloads/surfing_short.mov")
let videoAsset = AVAsset(url: inputPath)
let videoReader = VideoReader(videoAsset: videoAsset)!

let frameRate = videoReader.frameRate
let orientation = videoReader.orientation
let affineTransform = videoReader.affineTransform
let numFrames = videoReader.numFrames
let size = videoReader.size

// Create output
let outputPath = URL(fileURLWithPath: "/Users/peter/Downloads/surfing_tracked.mp4")
let outputSettings = AVOutputSettingsAssistant(preset: .preset1920x1080)!.videoSettings!
try? FileManager.default.removeItem(at: outputPath)
let videoWriter = VideoWriter(url: outputPath, fileType: .mp4, frameRate: Int(frameRate), settings: outputSettings)

// Create handler
let requestHandler = VNSequenceRequestHandler()

let initialEstimate = CGRect(x: 0.538, y: 0.334, width: 0.069, height: 0.227)
var observation = VNDetectedObjectObservation(boundingBox: initialEstimate)
print("Initial estimate: \(observation.boundingBox)")

var frameCount = 0
while true {
	// Read frame
	let frame = videoReader.nextFrame()
	if frame == nil {
		print("End of video")
		break
	}
	let pixelBuffer = frame!
	
	frameCount += 1
	//print("Frame \(frameCount) / \(numFrames)")
	
	// Track
	let request = VNTrackObjectRequest(detectedObjectObservation: observation)
	request.trackingLevel = .fast
	do {
		try requestHandler.perform([request], on: pixelBuffer, orientation: orientation)
	} catch {
		print("Tracking failed")
		break
	}
	
	observation = request.results!.first as! VNDetectedObjectObservation
	//print("Object at \(observation.boundingBox) with confidence \(observation.confidence)")
	print("Frame \(frameCount) / \(numFrames): confidence \(observation.confidence)")
	if observation.confidence < 0.5 {
		print("Tracking not confident enough")
		break
	}
	
	// Draw on image
	let unitRect = observation.boundingBox
	let t = CGAffineTransform(scaleX: size.width, y: size.height)
	let rect = unitRect.applying(t)
	
	let cgImage = pixelBuffer.toCGImage()!
	let ctx = cgImage.createCGContext()!
	ctx.setStrokeColor(red: 1, green: 0, blue: 0, alpha: 1)
	ctx.stroke(rect, width: 10)
	let outImg = ctx.makeImage()!
	ctx.data!.deallocate()
	
	// Write output
	let outFrame = outImg.createPixelBuffer()!
	videoWriter.writeFrame(pixelBuffer: outFrame)
	
//	outImg.saveImage(url: URL(fileURLWithPath: "/Users/peter/Downloads/surfing_tracked.png"))
//	break
}

// Close everything
videoWriter.closeSync()
print("Done")

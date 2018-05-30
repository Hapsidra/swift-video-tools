//
// Created by Максим Ефимов on 11.05.2018.
//

import AVFoundation

public func editVideoLayer(url: URL, musicURL: URL? = nil, presetName: String = AVAssetExportPresetMediumQuality, processLayer: @escaping (CALayer) -> (), completion: @escaping (URL) -> ()) {
    print(#function)
    let asset = AVAsset(url: url)
    let composition = AVMutableComposition()
    let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first!
    let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first!
    
    do {
        try compositionVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoTrack, at: kCMTimeZero)
        try compositionAudioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioTrack, at: kCMTimeZero)
    } catch {
        print(error)
    }
    
    if musicURL != nil {
        let compositionMusicTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let musicAsset = AVAsset(url: musicURL!)
        let musicAudioTrack = musicAsset.tracks(withMediaType: .audio).first!
        do {
            let repeatCount = Int(ceil(asset.duration.seconds / musicAsset.duration.seconds))
            for i in 0..<repeatCount {
                let duration = CMTime(seconds: min(musicAsset.duration.seconds, asset.duration.seconds - Double(i) * musicAsset.duration.seconds), preferredTimescale: 1000)
                let at = CMTime(seconds: Double(i) * musicAsset.duration.seconds, preferredTimescale: 1000)
                let range = CMTimeRangeMake(kCMTimeZero, duration)
                try compositionMusicTrack.insertTimeRange(range, of: musicAudioTrack, at: at)
            }
        } catch {
            print(error)
        }
    }
    
    compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
    
    var videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform); videoSize.width = abs(videoSize.width); videoSize.height = abs(videoSize.height)
    
    let parentLayer = CALayer()
    parentLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
    
    let videoLayer = CALayer()
    videoLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
    parentLayer.addSublayer(videoLayer)
    
    let customizableLayer = CALayer()
    customizableLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
    customizableLayer.masksToBounds = true
    processLayer(customizableLayer)
    parentLayer.addSublayer(customizableLayer)
    
    let videoComposition = AVMutableVideoComposition()
    videoComposition.frameDuration = CMTimeMake(1, 30)
    videoComposition.renderSize = videoSize
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration)
    
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
    layerInstruction.setTransform(compositionVideoTrack.preferredTransform, at: kCMTimeZero)
    
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]
    
    let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString.appending(".mp4")))
    if FileManager.default.fileExists(atPath: outputUrl.path) {
        do {
            try FileManager.default.removeItem(atPath: outputUrl.path)
        }
        catch {
            print(error)
        }
    }
    
    let exportSession = AVAssetExportSession(asset: composition, presetName: presetName)!
    exportSession.videoComposition = videoComposition
    exportSession.outputURL = outputUrl
    exportSession.outputFileType = AVFileType.mp4
    exportSession.shouldOptimizeForNetworkUse = true
    
    exportSession.exportAsynchronously(completionHandler: {
        if exportSession.status == AVAssetExportSessionStatus.completed {
            completion(outputUrl)
        } else {
            print("export error")
        }
    })
}

/*
 private func mergeVideoClips() {
 let composition = AVMutableComposition()
 let videoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
 let audioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
 var time: Double = 0.0
 
 for video in outputs {
 let asset = AVAsset(url: video)
 
 if let videoAssetTrack = asset.tracks(withMediaType: AVMediaType.video).first, let audioAssetTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
 let atTime = CMTime(seconds:time, preferredTimescale: 0)
 do {
 try videoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoAssetTrack, at: atTime)
 try audioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioAssetTrack, at: atTime)
 } catch {
 print("something bad happend I don't want to talk about it")
 }
 
 time+=asset.duration.seconds
 }
 }
 
 videoTrack?.preferredTransform = (videoTrack?.preferredTransform.rotated(by: .pi / 2))!
 videoTrack?.preferredTransform = (videoTrack?.preferredTransform.scaledBy(x: 1, y: -1))!
 
 let videoName = UUID().uuidString.appending(".mov")
 let videoExporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality)
 
 let outputURL = URL(fileURLWithPath: NSTemporaryDirectory().appending(videoName))
 videoExporter?.outputURL = outputURL
 videoExporter?.shouldOptimizeForNetworkUse = true
 videoExporter?.outputFileType = AVFileType.mov
 videoExporter?.exportAsynchronously(completionHandler: { () -> Void in
 print("video exporting complete", outputURL)
 DispatchQueue.main.async {
 self.delegate?.swiftVideoRecorder(didCompleteRecordingWithUrl: outputURL)
 }
 })
 }
 */

//
// Created by Максим Ефимов on 11.05.2018.
// Copyright (c) 2018 Platforma. All rights reserved.
//

import AVFoundation
import AssetsLibrary
import Photos

public func processVideo(url: URL, processLayer: @escaping (CALayer) -> (), completion: @escaping (URL) -> ()) {
    print(#function)
    let asset = AVAsset(url: url)
    let composition = AVMutableComposition()
    let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
    let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first!
    let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first!
    do {
        try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoTrack, at: kCMTimeZero)
        try compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioTrack, at: kCMTimeZero)
    } catch {
        print(error)
    }

    compositionVideoTrack?.preferredTransform = videoTrack.preferredTransform

    var videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform); videoSize.width = abs(videoSize.width); videoSize.height = abs(videoSize.height)
    print("size of video:", videoSize.width, videoSize.height)

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

    let resultVideoTrack = composition.tracks(withMediaType: AVMediaType.video).first! //may be compositionVideoTrack
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: resultVideoTrack)
    layerInstruction.setTransform(resultVideoTrack.preferredTransform, at: kCMTimeZero)

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

    let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetLowQuality)!
    exportSession.videoComposition = videoComposition
    exportSession.outputURL = outputUrl
    exportSession.outputFileType = AVFileType.mp4
    exportSession.shouldOptimizeForNetworkUse = true

    exportSession.exportAsynchronously(completionHandler: {
        if exportSession.status == AVAssetExportSessionStatus.completed {
            print("complete")
            completion(outputUrl)
        } else {
            print("export error")
        }
    })
}

public func saveVideoToLibrary(_ url: URL, useAssetsLibrary: Bool = false, completion: @escaping (URL?) -> ()) {
    print(#function)
    if PHPhotoLibrary.authorizationStatus() == .authorized {
        print("authorized")
        if useAssetsLibrary {
            ALAssetsLibrary().writeVideoAtPath(toSavedPhotosAlbum: url) { url, error in
                if error != nil {
                    print("error", error!)
                    completion(nil)
                } else if url != nil {
                    completion(url)
                } else {
                    completion(nil)
                }
            }
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { saved, error in
                if saved {
                    completion(url)
                } else if error != nil {
                    print(error!.localizedDescription)
                    completion(nil)
                }
            }
        }
    }
    else if PHPhotoLibrary.authorizationStatus() == .denied {
        completion(nil)
    }
    else {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                saveVideoToLibrary(url, completion: completion)
            } else {
                completion(nil)
            }
        }
    }
}

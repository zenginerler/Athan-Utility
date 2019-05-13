//
//  NoteSoundPlayer.swift
//  Athan Utility
//
//  Created by Omar Al-Ejel on 5/12/19.
//  Copyright © 2019 Omar Alejel. All rights reserved.
//

import UIKit
import AVFoundation

class NoteSoundPlayer: NSObject {
    
    private static var audioPlayer: AVAudioPlayer?
    private static var soundPreviewTimer: Timer?
    
    private static func playAudio(for index: Int, isPreview: Bool, fadeInterval: Int? = nil) {
        
        audioPlayer?.stop()
        
        do {
            var fileName = Settings.noteSoundFileNames[index]
            if fileName == "DEFAULT" {
                AudioServicesPlaySystemSound(1315);
            } else {
                if isPreview { fileName += "-preview" }
                if let asset = NSDataAsset(name: fileName) {
                    try audioPlayer = AVAudioPlayer(data: asset.data, fileTypeHint: "mp3")
                    // allow audio to play with ringer off
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
                    audioPlayer?.play()
                    soundPreviewTimer?.invalidate()
                    if let interval = fadeInterval {
                        soundPreviewTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: false) { (timer) in
                            self.audioPlayer?.setVolume(0, fadeDuration: 1)
                        }
                    }
                    
                }
            }
        } catch {
            fatalError("unable to play audio file")
        }
    }
    
    static func playPreviewAudio(for index: Int) {
        playAudio(for: index, isPreview: false)
    }
    
    static func playFullAudio(for index: Int, fadeInterval: Int? = nil) {
        playAudio(for: index, isPreview: true, fadeInterval: fadeInterval)
    }
    
    static func fadeAudio() {
        audioPlayer?.setVolume(0, fadeDuration: 1)
    }
    
    static func stopAudio() {
        audioPlayer?.stop()
    }
}
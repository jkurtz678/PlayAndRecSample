//
//  ViewController.swift
//  PlayAndRecSample
//
//  Created by Tadashi on 2017/03/02.
//  Copyright © 2017 T@d. All rights reserved.
//

import UIKit

import UIKit
import AVFoundation
import AudioToolbox

class ViewController: UIViewController {

	@IBOutlet weak var indicatorView: UIActivityIndicatorView!
	var audioEngine : AVAudioEngine!
	var audioFile : AVAudioFile!
	var audioPlayer : AVAudioPlayerNode!
	var outref: ExtAudioFileRef?
	var audioFilePlayer: AVAudioPlayerNode!
	var playerMixer : AVAudioMixerNode!
    var recorderMixer : AVAudioMixerNode!
    var inputNode : AVAudioInputNode!
	var filePath : String? = nil
	var isPlay = false
	var isRec = false

	@IBOutlet var play: UIButton!
	@IBAction func play(_ sender: Any) {

		if self.isPlay {
			self.play.setTitle("PLAY", for: .normal)
			self.indicator(value: false)
			self.stopPlay()
			self.rec.isEnabled = true
		} else {
			if self.startPlay() {
				self.rec.isEnabled = false
				self.play.setTitle("STOP", for: .normal)
				self.indicator(value: true)
			}
		}
	}

	@IBOutlet var rec: UIButton!
	@IBAction func rec(_ sender: Any) {
	
		if self.isRec {
			self.rec.setTitle("RECORDING", for: .normal)
			self.indicator(value: false)
			self.stopRecord()
			self.play.isEnabled = true
		} else {
			self.play.isEnabled = false
			self.rec.setTitle("STOP", for: .normal)
			self.indicator(value: true)
			self.startRecord()
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.audioEngine = AVAudioEngine()
		self.audioFilePlayer = AVAudioPlayerNode()
		self.playerMixer = AVAudioMixerNode()
        self.recorderMixer = AVAudioMixerNode()

		self.audioEngine.attach(audioFilePlayer)
		self.audioEngine.attach(playerMixer)
        self.audioEngine.attach(recorderMixer)
        self.inputNode = audioEngine.inputNode

		self.indicator(value: false)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) != .authorized {
			AVCaptureDevice.requestAccess(for: AVMediaType.audio,
				completionHandler: { (granted: Bool) in
			})
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	func startRecord() {

		self.filePath = nil

		self.isRec = true

        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: [AVAudioSessionCategoryOptions.defaultToSpeaker])
		try! AVAudioSession.sharedInstance().setActive(true)

		self.audioFile = try! AVAudioFile(forReading: Bundle.main.url(forResource: "humble", withExtension: "mp3")!)
        let sampleRate = self.inputNode.inputFormat(forBus: 0).sampleRate

		let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
			sampleRate: sampleRate,
			channels: 1,
			interleaved: true)
        
        
        self.audioEngine.connect(self.audioFilePlayer, to: self.playerMixer, format: self.audioFile.processingFormat)
        
        let recorderMixerPoint = AVAudioConnectionPoint(node: self.recorderMixer, bus: 0)
        let outputNodePoint = AVAudioConnectionPoint(node: self.audioEngine.mainMixerNode, bus: 0)
        
        self.audioEngine.connect(self.playerMixer, to: [recorderMixerPoint, outputNodePoint], fromBus: 0, format: self.audioFile.processingFormat)
        
        self.audioEngine.connect(inputNode, to: self.recorderMixer, format: format)

		self.audioFilePlayer.scheduleSegment(audioFile,
			startingFrame: AVAudioFramePosition(0),
			frameCount: AVAudioFrameCount(self.audioFile.length),
			at: nil,
			completionHandler: self.completion)

		let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
		self.filePath =  dir.appending("/temp.wav")

		_ = ExtAudioFileCreateWithURL(URL(fileURLWithPath: self.filePath!) as CFURL,
			kAudioFileWAVEType,
			(format?.streamDescription)!,
			nil,
			AudioFileFlags.eraseFile.rawValue,
			&outref)

		self.recorderMixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount((format?.sampleRate)! * 0.4), format: format, block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

			let audioBuffer : AVAudioBuffer = buffer
			_ = ExtAudioFileWrite(self.outref!, buffer.frameLength, audioBuffer.audioBufferList)
		})

		try! self.audioEngine.start()
		self.audioFilePlayer.play()
	}

	func stopRecord() {
		self.isRec = false
		self.audioFilePlayer.stop()
		self.audioEngine.stop()
		self.recorderMixer.removeTap(onBus: 0)
		ExtAudioFileDispose(self.outref!)
		try! AVAudioSession.sharedInstance().setActive(false)
	}

	func startPlay() -> Bool {
	
		if self.filePath == nil {
			return	false
		}

		self.isPlay = true

		try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
		try! AVAudioSession.sharedInstance().setActive(true)

		self.audioFile = try! AVAudioFile(forReading: URL(fileURLWithPath: self.filePath!))

		self.audioEngine.connect(self.audioFilePlayer, to: self.audioEngine.mainMixerNode, format: audioFile.processingFormat)

		self.audioFilePlayer.scheduleSegment(audioFile,
			startingFrame: AVAudioFramePosition(0),
			frameCount: AVAudioFrameCount(self.audioFile.length),
			at: nil,
			completionHandler: self.completion)

		try! self.audioEngine.start()
		self.audioFilePlayer.play()

		return true
	}
	
	func stopPlay() {
		self.isPlay = false
		if self.audioFilePlayer != nil && self.audioFilePlayer.isPlaying {
			self.audioFilePlayer.stop()
		}
		self.audioEngine.stop()
		try! AVAudioSession.sharedInstance().setActive(false)
	}

	func completion() {

		if self.isRec {
			DispatchQueue.main.async {
				self.rec(UIButton())
			}
		} else if self.isPlay {
			DispatchQueue.main.async {
				self.play(UIButton())
			}
		}
	}
	
	func indicator(value: Bool) {
	
		DispatchQueue.main.async {
			if value {
				self.indicatorView.startAnimating()
				self.indicatorView.isHidden = false
			} else {
				self.indicatorView.stopAnimating()
				self.indicatorView.isHidden = true
			}
		}
	}
}

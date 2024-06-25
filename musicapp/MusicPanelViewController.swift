//
//  MusicPanelViewController.swift
//  musicapp
//
//  Created by Samet Özbalkan on 25.06.2024.
//

import UIKit
import AVFoundation
import MediaPlayer

class MusicPanelViewController: UIViewController {

    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var musicSlider: UISlider!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!

    var audioPlayer: AVAudioPlayer?
    var currentItem: MPMediaItem?
    var currentLocalItem: LocalMusicItem?
    var currentIndex: Int = 0
    var isRepeat: Bool = false
    var timer: Timer?
    var playlist: [Any] = []
    var musicFiles: [MPMediaItem] = []
    var localMusicFiles: [LocalMusicItem] = []
    var playMode: ViewController.PlayMode = .all
    weak var delegate: ViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let item = currentItem {
            playMusic(with: item)
            updateLikeButton(for: item)
        } else if let localItem = currentLocalItem {
            playMusic(from: localItem.url)
            updateLikeButton(for: localItem)
        }

        musicSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let item = currentItem {
            updateLikeButton(for: item)
        } else if let localItem = currentLocalItem {
            updateLikeButton(for: localItem)
        }
    }

    func playMusic(with item: MPMediaItem) {
        guard let url = item.assetURL else { return }
        playMusic(from: url)
    }

    func playMusic(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            updateUI(with: url)
            startTimer()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    func updateLikeButton(for item: MPMediaItem) {
        if playlist.contains(where: { ($0 as? MPMediaItem)?.persistentID == item.persistentID }) {
            let image = UIImage(named: "unliked")
            likeButton.setImage(image, for: .normal)
        } else {
            let image = UIImage(named: "liked")
            likeButton.setImage(image, for: .normal)
        }
    }

    func updateLikeButton(for localItem: LocalMusicItem) {

        if playlist.contains(where: { ($0 as? LocalMusicItem)?.url == localItem.url }) {
            let image = UIImage(named: "unliked")
            likeButton.setImage(image, for: .normal)
        } else {
            let image = UIImage(named: "liked")
            likeButton.setImage(image, for: .normal)
        }
    }

    @IBAction func likeTapped(sender: UIButton) {
        if let item = currentItem {
            if playlist.contains(where: { ($0 as? MPMediaItem)?.persistentID == item.persistentID }) {
                delegate?.removeFromPlaylist(item: item)
                let image = UIImage(named: "liked")
                sender.setImage(image, for: .normal)
            } else {
                delegate?.addToPlaylist(item: item)
                let image = UIImage(named: "unliked")
                sender.setImage(image, for: .normal)
            }
        } else if let localItem = currentLocalItem {
            if playlist.contains(where: { ($0 as? LocalMusicItem)?.url == localItem.url }) {
                delegate?.removeFromPlaylist(localItem: localItem)
                let image = UIImage(named: "liked")
                sender.setImage(image, for: .normal)
            } else {
                delegate?.addToPlaylist(localItem: localItem)
                let image = UIImage(named: "unliked")
                sender.setImage(image, for: .normal)
            }
        }
    }

    func updateUI(with url: URL) {
        songTitleLabel.text = url.lastPathComponent
        albumImageView.image = UIImage(named: "music")
        musicSlider.maximumValue = Float(audioPlayer?.duration ?? 0)
        musicSlider.value = 0
        updateLabels()
    }

    @IBAction func playPauseTapped(sender: UIButton) {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
            let image = UIImage(named: "play")
            sender.setImage(image, for: .normal)
        } else {
            audioPlayer?.play()
            let image = UIImage(named: "pause")
            sender.setImage(image, for: .normal)
            startTimer()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let audioPlayer = audioPlayer, audioPlayer.isPlaying {
            audioPlayer.stop()
        }
    }

    @IBAction func previousTapped(sender: UIButton) {
        guard currentSongList().count > 0 else { return }
        currentIndex = (currentIndex - 1 + currentSongList().count) % currentSongList().count
        playCurrentSong()
    }

    @IBAction func nextTapped(sender: UIButton) {
        guard currentSongList().count > 0 else { return }
        currentIndex = (currentIndex + 1) % currentSongList().count
        playCurrentSong()
    }

    func playCurrentSong() {
        let songList = currentSongList()
        guard songList.indices.contains(currentIndex) else { return }

        let playPauseImage = UIImage(named: "pause")
        playPauseButton.setImage(playPauseImage, for: .normal)

        if let item = songList[currentIndex] as? MPMediaItem {
            updateLikeButton(for: item)
        } else if let localItem = songList[currentIndex] as? LocalMusicItem {
            updateLikeButton(for: localItem)
        }
        
        isRepeat = false;
        let repeatImage = isRepeat ? UIImage(named: "replay-selected") : UIImage(named: "replay")
        repeatButton.setImage(repeatImage, for: .normal)

        if let item = songList[currentIndex] as? MPMediaItem {
            playMusic(with: item)
        } else if let localItem = songList[currentIndex] as? LocalMusicItem {
            playMusic(from: localItem.url)
        }
    }

    func currentSongList() -> [Any] {
        return playMode == .all ? (musicFiles as [Any]) + localMusicFiles : playlist
    }

    @IBAction func repeatTapped(sender: UIButton) {
        isRepeat.toggle()
        let image = isRepeat ? UIImage(named: "replay-selected") : UIImage(named: "replay")
        sender.setImage(image, for: .normal)
    }

    @objc func sliderValueChanged(_ sender: UISlider) {
        audioPlayer?.currentTime = TimeInterval(sender.value)
        updateLabels()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }

    @objc func updateSlider() {
        musicSlider.value = Float(audioPlayer?.currentTime ?? 0)
        updateLabels()
    }

    func updateLabels() {
        let currentTime = audioPlayer?.currentTime ?? 0
        let duration = audioPlayer?.duration ?? 0
        let currentMinutes = Int(currentTime) / 60
        let currentSeconds = Int(currentTime) % 60
        let durationMinutes = Int(duration) / 60
        let durationSeconds = Int(duration) % 60
        timeLabel.text = String(format: "%02d:%02d", currentMinutes, currentSeconds)
        totalTimeLabel.text = String(format: "%02d:%02d", durationMinutes, durationSeconds)
    }
}

extension MusicPanelViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isRepeat {
            player.play()
        } else {
            nextTapped(sender: nextButton)
        }
    }
}

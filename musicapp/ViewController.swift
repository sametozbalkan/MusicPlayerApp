//
//  ViewController.swift
//  musicapp
//
//  Created by Samet Özbalkan on 25.06.2024.
//

import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ViewControllerDelegate {

    @IBOutlet weak var allMusicTableView: UITableView!
    @IBOutlet weak var playlistTableView: UITableView!
    @IBOutlet weak var playModeSegmentedControl: UISegmentedControl!

    var musicFiles: [MPMediaItem] = []
    var localMusicFiles: [LocalMusicItem] = []
    var playlist: [Any] = []
    var currentIndex: Int = 0
    var playMode: PlayMode = .all

    enum PlayMode {
        case all
        case playlist
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        allMusicTableView.delegate = self
        allMusicTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.dataSource = self

        playModeSegmentedControl.addTarget(self, action: #selector(changePlayMode), for: .valueChanged)

        MediaLibraryManager.getAuthorization { authorized in
            if authorized {
                self.loadMediaLibrary()
            } else {
                print("Medya kütüphanesi izni verilmedi.")
            }
        }
    }

    func addToPlaylist(item: MPMediaItem) {
        if !playlist.contains(where: { ($0 as? MPMediaItem)?.persistentID == item.persistentID }) {
            playlist.append(item)
            DispatchQueue.main.async {
                self.playlistTableView.reloadData()
            }
        }
    }

    func addToPlaylist(localItem: LocalMusicItem) {
        if !playlist.contains(where: { ($0 as? LocalMusicItem)?.url == localItem.url }) {
            playlist.append(localItem)
            DispatchQueue.main.async {
                self.playlistTableView.reloadData()
            }
        }
    }

    func removeFromPlaylist(item: MPMediaItem) {
        if let index = playlist.firstIndex(where: { ($0 as? MPMediaItem)?.persistentID == item.persistentID }) {
            playlist.remove(at: index)
            DispatchQueue.main.async {
                self.playlistTableView.reloadData()
            }
        }
    }

    func removeFromPlaylist(localItem: LocalMusicItem) {
        if let index = playlist.firstIndex(where: { ($0 as? LocalMusicItem)?.url == localItem.url }) {
            playlist.remove(at: index)
            DispatchQueue.main.async {
                self.playlistTableView.reloadData()
            }
        }
    }

    @objc func changePlayMode(segmentedControl: UISegmentedControl) {
        playMode = segmentedControl.selectedSegmentIndex == 0 ? .all : .playlist
        DispatchQueue.main.async {
            self.allMusicTableView.reloadData()
            self.playlistTableView.reloadData()
        }
    }

    func loadMediaLibrary() {
        let query = MPMediaQuery.songs()
        if let items = query.items {
            musicFiles = items
        }

        if let resourcePath = Bundle.main.resourcePath {
            let fm = FileManager.default
            do {
                let items = try fm.contentsOfDirectory(atPath: resourcePath)
                for item in items {
                    if item.hasSuffix(".mp3") {
                        let itemPath = (resourcePath as NSString).appendingPathComponent(item)
                        let url = URL(fileURLWithPath: itemPath)
                        let localMusic = LocalMusicItem(url: url, title: item, artist: "Bilinmeyen Sanatçı")
                        localMusicFiles.append(localMusic)
                    }
                }
            } catch {
                print("Hata: \(error.localizedDescription)")
            }
        }

        DispatchQueue.main.async {
            self.allMusicTableView.reloadData()
        }
    }

    func currentSongList() -> [Any] {
        return playMode == .all ? (musicFiles as [Any]) + localMusicFiles : playlist
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.playlistTableView {
            return playlist.count
        }

        switch playMode {
        case .all:
            return musicFiles.count + localMusicFiles.count
        case .playlist:
            return playlist.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)

        if playMode == .all {
            if indexPath.row < musicFiles.count {
                let item = musicFiles[indexPath.row]
                cell.textLabel?.text = item.title ?? "Başlık Yok"
                cell.detailTextLabel?.text = item.artist ?? "Bilinmeyen Sanatçı"
            } else {
                let localItem = localMusicFiles[indexPath.row - musicFiles.count]
                cell.textLabel?.text = localItem.title
                cell.detailTextLabel?.text = localItem.artist
            }
        } else {
            let item = playlist[indexPath.row]
            if let mediaItem = item as? MPMediaItem {
                cell.textLabel?.text = mediaItem.title ?? "Başlık Yok"
                cell.detailTextLabel?.text = mediaItem.artist ?? "Bilinmeyen Sanatçı"
            } else if let localItem = item as? LocalMusicItem {
                cell.textLabel?.text = localItem.title
                cell.detailTextLabel?.text = localItem.artist
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if playMode == .all {
            if indexPath.row < musicFiles.count {
                let item = musicFiles[indexPath.row]
                openMusicPanel(with: item, at: indexPath.row)
                addToPlaylist(item: item)
            } else {
                let localItem = localMusicFiles[indexPath.row - musicFiles.count]
                openMusicPanel(with: localItem, at: indexPath.row - musicFiles.count)
            }
        } else {
            let item = playlist[indexPath.row]
            if let mediaItem = item as? MPMediaItem {
                openMusicPanel(with: mediaItem, at: indexPath.row)
            } else if let localItem = item as? LocalMusicItem {
                openMusicPanel(with: localItem, at: indexPath.row)
            }
        }
    }

    func openMusicPanel(with item: MPMediaItem, at index: Int) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let musicPanelVC = storyboard.instantiateViewController(withIdentifier: "MusicPanelViewController") as? MusicPanelViewController {
            musicPanelVC.currentItem = item
            musicPanelVC.currentIndex = index
            musicPanelVC.playlist = playlist
            musicPanelVC.musicFiles = musicFiles
            musicPanelVC.localMusicFiles = localMusicFiles
            musicPanelVC.playMode = playMode
            musicPanelVC.delegate = self
            navigationController?.pushViewController(musicPanelVC, animated: true)
        }
    }

    func openMusicPanel(with localItem: LocalMusicItem, at index: Int) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let musicPanelVC = storyboard.instantiateViewController(withIdentifier: "MusicPanelViewController") as? MusicPanelViewController {
            musicPanelVC.currentLocalItem = localItem
            musicPanelVC.currentIndex = index
            musicPanelVC.playlist = playlist
            musicPanelVC.musicFiles = musicFiles
            musicPanelVC.localMusicFiles = localMusicFiles
            musicPanelVC.playMode = playMode
            musicPanelVC.delegate = self
            navigationController?.pushViewController(musicPanelVC, animated: true)
        }
    }
}

protocol ViewControllerDelegate: AnyObject {
    func addToPlaylist(item: MPMediaItem)
    func removeFromPlaylist(item: MPMediaItem)
    func addToPlaylist(localItem: LocalMusicItem)
    func removeFromPlaylist(localItem: LocalMusicItem)
}

class MediaLibraryManager {
    static func getAuthorization(completionHandler: @escaping (Bool) -> Void) {
        if MPMediaLibrary.authorizationStatus() == .authorized {
            completionHandler(true)
        } else {
            MPMediaLibrary.requestAuthorization { completionHandler($0 == .authorized) }
        }
    }
}

struct LocalMusicItem {
    var url: URL
    var title: String
    var artist: String
}

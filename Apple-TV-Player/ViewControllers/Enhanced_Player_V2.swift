import UIKit
import AVKit

// MARK: - Enhanced Player with Channel Navigation & EPG Guide

class EnhancedPlayerViewController: AVPlayerViewController {
    
    // MARK: Properties
    
    var currentChannels: [M3UParser.Channel] = []
    var currentChannelIndex: Int = 0
    var epgData: EPGData?
    var epgOverlayView: PlayerEPGOverlayView?
    var epgGuideViewController: EPGGuideViewController?
    
    // EPG API URL
    private let epgAPIURL = "http://kjhoraclea3.duckdns.org:8999/myepg/api/epgall"
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRemoteGestureRecognizers()
        loadEPGData()
        createPlayerOverlay()
    }
    
    // MARK: - Remote Control Setup
    
    private func setupRemoteGestureRecognizers() {
        // tvOS Siri Remote 제스처 인식
        
        // 위쪽 스와이프 - 이전 채널
        let upSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleUpSwipe))
        upSwipe.direction = .up
        view.addGestureRecognizer(upSwipe)
        
        // 아래쪽 스와이프 - 다음 채널
        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleDownSwipe))
        downSwipe.direction = .down
        view.addGestureRecognizer(downSwipe)
        
        // 좌측 스와이프 - 재생/일시정지 토글
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(togglePlayPause))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
        
        // 우측 스와이프 - EPG 가이드 화면 열기
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(openEPGGuide))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        
        // 탭 제스처 - 메뉴 토글
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }
    
    // MARK: - Channel Navigation
    
    @objc private func handleUpSwipe() {
        previousChannel()
    }
    
    @objc private func handleDownSwipe() {
        nextChannel()
    }
    
    func nextChannel() {
        guard !currentChannels.isEmpty else { return }
        currentChannelIndex = (currentChannelIndex + 1) % currentChannels.count
        playSelectedChannel()
    }
    
    func previousChannel() {
        guard !currentChannels.isEmpty else { return }
        currentChannelIndex = (currentChannelIndex - 1 + currentChannels.count) % currentChannels.count
        playSelectedChannel()
    }
    
    private func playSelectedChannel() {
        let channel = currentChannels[currentChannelIndex]
        
        // 채널 정보 업데이트
        title = channel.name
        
        // 동영상 URL 로드 및 재생
        if let streamURL = URL(string: channel.url) {
            let asset = AVAsset(url: streamURL)
            let playerItem = AVPlayerItem(asset: asset)
            player?.replaceCurrentItem(with: playerItem)
            player?.play()
        }
        
        // EPG 오버레이 업데이트
        updatePlayerOverlay()
        
        // 채널 전환 피드백
        showChannelChangeNotification()
    }
    
    // MARK: - Player Overlay (현재/다음 프로그램만)
    
    private func createPlayerOverlay() {
        let overlay = PlayerEPGOverlayView()
        overlay.frame = CGRect(x: 0, y: view.bounds.height - 100, width: view.bounds.width, height: 100)
        view.addSubview(overlay)
        epgOverlayView = overlay
    }
    
    private func updatePlayerOverlay() {
        guard let epgData = epgData else { return }
        
        let channel = currentChannels[currentChannelIndex]
        let channelId = channel.tvgId ?? channel.id
        
        let currentProgram = EPGService.shared.getCurrentProgram(for: channelId, in: epgData)
        let nextProgram = EPGService.shared.getNextProgram(for: channelId, in: epgData)
        
        epgOverlayView?.updateWith(
            channelName: channel.name,
            currentProgram: currentProgram,
            nextProgram: nextProgram
        )
    }
    
    // MARK: - EPG Guide Screen
    
    @objc private func openEPGGuide() {
        guard let epgData = epgData else {
            print("EPG 데이터를 로드 중입니다...")
            return
        }
        
        let epgGuide = EPGGuideViewController()
        epgGuide.epgData = epgData
        epgGuide.channels = currentChannels
        epgGuide.currentChannelIndex = currentChannelIndex
        epgGuide.delegate = self
        
        let navVC = UINavigationController(rootViewController: epgGuide)
        navVC.modalPresentationStyle = .fullScreen
        present(navVC, animated: true)
    }
    
    // MARK: - EPG Management
    
    private func loadEPGData() {
        EPGService.shared.fetchEPGData(from: epgAPIURL) { [weak self] epgData in
            self?.epgData = epgData
            self?.updatePlayerOverlay()
        }
    }
    
    // MARK: - Playback Control
    
    @objc private func togglePlayPause() {
        if let player = player {
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    @objc private func handleTap() {
        // 메뉴 토글 (기본 동작 유지)
    }
    
    // MARK: - UI Feedback
    
    private func showChannelChangeNotification() {
        let channel = currentChannels[currentChannelIndex]
        
        let label = UILabel()
        label.text = "📺 \(channel.name)"
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        
        view.addSubview(label)
        label.frame = CGRect(x: 100, y: 80, width: view.bounds.width - 200, height: 80)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            label.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                UIView.animate(withDuration: 0.3, animations: {
                    label.alpha = 0
                }) { _ in
                    label.removeFromSuperview()
                }
            }
        }
    }
}

// MARK: - EPG Guide Delegate

extension EnhancedPlayerViewController: EPGGuideDelegate {
    func epgGuideDidSelectChannel(_ channelIndex: Int) {
        currentChannelIndex = channelIndex
        playSelectedChannel()
    }
}

// MARK: - Player EPG Overlay View (간단한 바)

class PlayerEPGOverlayView: UIView {
    
    private let containerView = UIView()
    private let channelLabel = UILabel()
    private let currentProgramLabel = UILabel()
    private let timeLabel = UILabel()
    private let nextProgramLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.borderColor = UIColor.cyan.cgColor
        layer.borderWidth = 1
        
        // 채널명
        channelLabel.font = .systemFont(ofSize: 16, weight: .bold)
        channelLabel.textColor = .white
        addSubview(channelLabel)
        
        // 현재 프로그램 (한줄)
        currentProgramLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        currentProgramLabel.textColor = .cyan
        currentProgramLabel.lineBreakMode = .byTruncatingTail
        addSubview(currentProgramLabel)
        
        // 시간
        timeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = .lightGray
        addSubview(timeLabel)
        
        // 다음 프로그램 (한줄)
        nextProgramLabel.font = .systemFont(ofSize: 12, weight: .regular)
        nextProgramLabel.textColor = .gray
        nextProgramLabel.lineBreakMode = .byTruncatingTail
        addSubview(nextProgramLabel)
        
        setupConstraints()
        
        // 1초마다 시간 업데이트
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func setupConstraints() {
        channelLabel.translatesAutoresizingMaskIntoConstraints = false
        currentProgramLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        nextProgramLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            channelLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            channelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            channelLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),
            
            currentProgramLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            currentProgramLabel.leadingAnchor.constraint(equalTo: channelLabel.trailingAnchor, constant: 16),
            currentProgramLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            currentProgramLabel.heightAnchor.constraint(equalToConstant: 18),
            
            timeLabel.topAnchor.constraint(equalTo: currentProgramLabel.bottomAnchor, constant: 2),
            timeLabel.leadingAnchor.constraint(equalTo: channelLabel.trailingAnchor, constant: 16),
            timeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
            
            nextProgramLabel.topAnchor.constraint(equalTo: currentProgramLabel.bottomAnchor, constant: 2),
            nextProgramLabel.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 8),
            nextProgramLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    func updateWith(channelName: String, currentProgram: EPGProgram?, nextProgram: EPGProgram?) {
        channelLabel.text = channelName
        
        if let current = currentProgram {
            currentProgramLabel.text = "지금: \(current.title)"
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            if let startDate = parseEPGDate(current.start),
               let endDate = parseEPGDate(current.stop) {
                timeLabel.text = "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        } else {
            currentProgramLabel.text = "프로그램 정보 없음"
            timeLabel.text = ""
        }
        
        if let next = nextProgram {
            nextProgramLabel.text = "다음: \(next.title)"
        } else {
            nextProgramLabel.text = "다음 프로그램 없음"
        }
    }
    
    private func updateCurrentTime() {
        // 실시간 시간 표시 업데이트
    }
    
    private func parseEPGDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let cleanDate = String(dateString.prefix(14))
        return formatter.date(from: cleanDate)
    }
}

// MARK: - EPG Guide Screen (모든 채널 EPG)

protocol EPGGuideDelegate: AnyObject {
    func epgGuideDidSelectChannel(_ channelIndex: Int)
}

class EPGGuideViewController: UIViewController {
    
    var epgData: EPGData?
    var channels: [M3UParser.Channel] = []
    var currentChannelIndex: Int = 0
    weak var delegate: EPGGuideDelegate?
    
    private var tableView: UITableView!
    private let epgService = EPGService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "📺 EPG 가이드"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        view.backgroundColor = .black
        
        setupTableView()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = .darkGray
        navigationController?.navigationBar.tintColor = .cyan
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        tableView.rowHeight = 120
        tableView.register(EPGGuideCell.self, forCellReuseIdentifier: "EPGGuideCell")
        
        view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // 현재 채널로 스크롤
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let indexPath = IndexPath(row: self.currentChannelIndex, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - EPG Guide TableView DataSource & Delegate

extension EPGGuideViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EPGGuideCell", for: indexPath) as! EPGGuideCell
        
        let channel = channels[indexPath.row]
        let channelId = channel.tvgId ?? channel.id
        
        let currentProgram = epgData != nil ? epgService.getCurrentProgram(for: channelId, in: epgData!) : nil
        let nextProgram = epgData != nil ? epgService.getNextProgram(for: channelId, in: epgData!) : nil
        
        let isCurrentChannel = (indexPath.row == currentChannelIndex)
        
        cell.configure(
            channelName: channel.name,
            currentProgram: currentProgram,
            nextProgram: nextProgram,
            isCurrentChannel: isCurrentChannel
        )
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        currentChannelIndex = indexPath.row
        delegate?.epgGuideDidSelectChannel(indexPath.row)
        
        // 선택된 채널로 하이라이트
        tableView.reloadData()
        
        // 약간의 딜레이 후 종료
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss(animated: true)
        }
    }
}

// MARK: - EPG Guide Cell

class EPGGuideCell: UITableViewCell {
    
    private let containerView = UIView()
    private let channelLabel = UILabel()
    private let currentProgramLabel = UILabel()
    private let currentTimeLabel = UILabel()
    private let nextProgramLabel = UILabel()
    private let nextTimeLabel = UILabel()
    private let progressView = UIProgressView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .black
        contentView.backgroundColor = .black
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = UIColor.cyan.withAlphaComponent(0.2)
        
        // 컨테이너
        containerView.layer.borderColor = UIColor.darkGray.cgColor
        containerView.layer.borderWidth = 1
        containerView.layer.cornerRadius = 8
        containerView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.2)
        contentView.addSubview(containerView)
        
        // 채널명
        channelLabel.font = .systemFont(ofSize: 18, weight: .bold)
        channelLabel.textColor = .white
        containerView.addSubview(channelLabel)
        
        // 현재 프로그램
        currentProgramLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        currentProgramLabel.textColor = .cyan
        currentProgramLabel.numberOfLines = 1
        currentProgramLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(currentProgramLabel)
        
        // 현재 시간
        currentTimeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.textColor = .lightGray
        containerView.addSubview(currentTimeLabel)
        
        // 다음 프로그램
        nextProgramLabel.font = .systemFont(ofSize: 13, weight: .regular)
        nextProgramLabel.textColor = .gray
        nextProgramLabel.numberOfLines = 1
        nextProgramLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nextProgramLabel)
        
        // 다음 시간
        nextTimeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        nextTimeLabel.textColor = .darkGray
        containerView.addSubview(nextTimeLabel)
        
        // 프로그레스 바 (현재 프로그램 진행도)
        progressView.progressTintColor = .cyan
        progressView.trackTintColor = UIColor.gray.withAlphaComponent(0.3)
        containerView.addSubview(progressView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
        
        channelLabel.translatesAutoresizingMaskIntoConstraints = false
        currentProgramLabel.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        nextProgramLabel.translatesAutoresizingMaskIntoConstraints = false
        nextTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 채널명
            channelLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            channelLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            channelLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
            
            // 현재 프로그램
            currentProgramLabel.topAnchor.constraint(equalTo: channelLabel.bottomAnchor, constant: 6),
            currentProgramLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            currentProgramLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // 현재 시간
            currentTimeLabel.topAnchor.constraint(equalTo: currentProgramLabel.bottomAnchor, constant: 4),
            currentTimeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            
            // 프로그레스 바
            progressView.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 6),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            // 다음 프로그램
            nextProgramLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            nextProgramLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nextProgramLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // 다음 시간
            nextTimeLabel.topAnchor.constraint(equalTo: nextProgramLabel.bottomAnchor, constant: 2),
            nextTimeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12)
        ])
    }
    
    func configure(
        channelName: String,
        currentProgram: EPGProgram?,
        nextProgram: EPGProgram?,
        isCurrentChannel: Bool
    ) {
        channelLabel.text = channelName
        if isCurrentChannel {
            channelLabel.textColor = .cyan
            containerView.layer.borderColor = UIColor.cyan.cgColor
            containerView.backgroundColor = UIColor.cyan.withAlphaComponent(0.1)
        } else {
            channelLabel.textColor = .white
            containerView.layer.borderColor = UIColor.darkGray.cgColor
            containerView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.2)
        }
        
        if let current = currentProgram {
            currentProgramLabel.text = current.title
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            if let startDate = parseEPGDate(current.start),
               let endDate = parseEPGDate(current.stop) {
                let startStr = formatter.string(from: startDate)
                let endStr = formatter.string(from: endDate)
                currentTimeLabel.text = "\(startStr) - \(endStr)"
                
                // 진행도 표시
                let now = Date()
                let progress = Float((now.timeIntervalSince(startDate)) / (endDate.timeIntervalSince(startDate)))
                progressView.progress = max(0, min(1, progress))
            }
        } else {
            currentProgramLabel.text = "프로그램 정보 없음"
            currentTimeLabel.text = ""
            progressView.progress = 0
        }
        
        if let next = nextProgram {
            nextProgramLabel.text = "▶️ \(next.title)"
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if let startDate = parseEPGDate(next.start) {
                nextTimeLabel.text = formatter.string(from: startDate)
            }
        } else {
            nextProgramLabel.text = "다음 프로그램 없음"
            nextTimeLabel.text = ""
        }
    }
    
    private func parseEPGDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let cleanDate = String(dateString.prefix(14))
        return formatter.date(from: cleanDate)
    }
}

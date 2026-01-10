import Foundation

// MARK: - EPG Models

/// XMLTV 형식의 채널 정보
struct EPGChannel: Codable, Hashable {
    let id: String
    let displayNames: [String]
    
    var primaryName: String {
        displayNames.first ?? id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayNames = "display-name"
    }
}

/// XMLTV 형식의 프로그램 정보
struct EPGProgram: Codable {
    let channel: String
    let start: String
    let stop: String
    let title: String
    let description: String?
    let category: [String]?
    
    enum CodingKeys: String, CodingKey {
        case channel
        case start
        case stop
        case title
        case description = "desc"
        case category
    }
}

/// 파싱된 EPG 데이터
struct EPGData {
    let channels: [String: EPGChannel]
    let programs: [EPGProgram]
    
    subscript(channelId: String) -> [EPGProgram] {
        programs.filter { $0.channel == channelId }
    }
}

// MARK: - Parser

class XMLTVParser: NSObject, XMLParserDelegate {
    var channels: [String: EPGChannel] = [:]
    var programs: [EPGProgram] = []
    
    private var currentElement = ""
    private var currentChannelId = ""
    private var currentDisplayNames: [String] = []
    private var currentProgramData: [String: String] = [:]
    private var currentCategories: [String] = []
    
    var completion: ((EPGData?) -> Void)?
    
    func parseXMLTVFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            completion?(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.completion?(nil)
                }
                return
            }
            
            let parser = XMLParser(data: data)
            parser.delegate = self
            
            if parser.parse() {
                DispatchQueue.main.async {
                    let epgData = EPGData(channels: self?.channels ?? [:], programs: self?.programs ?? [])
                    self?.completion?(epgData)
                }
            } else {
                DispatchQueue.main.async {
                    self?.completion?(nil)
                }
            }
        }
        task.resume()
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "channel" {
            if let id = attributeDict["id"] {
                currentChannelId = id
                currentDisplayNames = []
            }
        } else if elementName == "programme" {
            currentProgramData = attributeDict
            currentCategories = []
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if currentElement == "display-name" {
            currentDisplayNames.append(trimmed)
        } else if currentElement == "title" {
            currentProgramData["title"] = trimmed
        } else if currentElement == "desc" {
            currentProgramData["desc"] = trimmed
        } else if currentElement == "category" {
            currentCategories.append(trimmed)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "channel" {
            if !currentChannelId.isEmpty && !currentDisplayNames.isEmpty {
                channels[currentChannelId] = EPGChannel(id: currentChannelId, displayNames: currentDisplayNames)
            }
            currentChannelId = ""
            currentDisplayNames = []
        } else if elementName == "programme" {
            if let channel = currentProgramData["channel"],
               let start = currentProgramData["start"],
               let stop = currentProgramData["stop"],
               let title = currentProgramData["title"] {
                let program = EPGProgram(
                    channel: channel,
                    start: start,
                    stop: stop,
                    title: title,
                    description: currentProgramData["desc"],
                    category: currentCategories.isEmpty ? nil : currentCategories
                )
                programs.append(program)
            }
            currentProgramData = [:]
            currentCategories = []
        }
    }
}

// MARK: - EPG Service

class EPGService {
    static let shared = EPGService()
    
    private var cachedEPGData: EPGData?
    private var lastUpdateTime: Date?
    private let cacheExpiration: TimeInterval = 3600 // 1시간
    
    func fetchEPGData(from urlString: String, completion: @escaping (EPGData?) -> Void) {
        // 캐시 확인
        if let cached = cachedEPGData,
           let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < cacheExpiration {
            completion(cached)
            return
        }
        
        let parser = XMLTVParser()
        parser.completion = { [weak self] epgData in
            if let epgData = epgData {
                self?.cachedEPGData = epgData
                self?.lastUpdateTime = Date()
            }
            completion(epgData)
        }
        parser.parseXMLTVFromURL(urlString)
    }
    
    func getCurrentProgram(for channelId: String, in epgData: EPGData) -> EPGProgram? {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        
        return epgData[channelId].first { program in
            guard let startDate = parseEPGDate(program.start),
                  let endDate = parseEPGDate(program.stop) else {
                return false
            }
            return startDate <= now && now < endDate
        }
    }
    
    func getNextProgram(for channelId: String, in epgData: EPGData) -> EPGProgram? {
        let now = Date()
        
        return epgData[channelId].first { program in
            guard let startDate = parseEPGDate(program.start) else {
                return false
            }
            return startDate > now
        }
    }
    
    private func parseEPGDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        
        // "20260110200000" 형식 파싱
        let cleanDate = String(dateString.prefix(14))
        return formatter.date(from: cleanDate)
    }
}

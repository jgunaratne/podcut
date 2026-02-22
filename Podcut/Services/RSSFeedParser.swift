import Foundation

/// Parses a podcast RSS feed and extracts episodes.
final class RSSFeedParser: NSObject, XMLParserDelegate {
    private var episodes: [Episode] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentAudioURL: String?
    private var currentPubDate = ""
    private var currentDuration = ""
    private var insideItem = false

    private var continuation: CheckedContinuation<[Episode], Error>?

    /// Fetch and parse episodes from the given feed URL.
    func parse(feedURL: URL) async throws -> [Episode] {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.episodes = []
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }
    }

    // MARK: - XMLParserDelegate

    nonisolated func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        MainActor.assumeIsolated {
            currentElement = elementName
            if elementName == "item" {
                insideItem = true
                currentTitle = ""
                currentDescription = ""
                currentAudioURL = nil
                currentPubDate = ""
                currentDuration = ""
            }
            if elementName == "enclosure", insideItem {
                currentAudioURL = attributeDict["url"]
            }
        }
    }

    nonisolated func parser(
        _ parser: XMLParser, foundCharacters string: String
    ) {
        MainActor.assumeIsolated {
            guard insideItem else { return }
            switch currentElement {
            case "title":
                currentTitle += string
            case "description":
                currentDescription += string
            case "pubDate":
                currentPubDate += string
            case "itunes:duration":
                currentDuration += string
            default:
                break
            }
        }
    }

    nonisolated func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        MainActor.assumeIsolated {
            if elementName == "item" {
                let episode = Episode(
                    title: currentTitle.trimmingCharacters(
                        in: .whitespacesAndNewlines),
                    description: currentDescription.trimmingCharacters(
                        in: .whitespacesAndNewlines),
                    audioURL: currentAudioURL.flatMap { URL(string: $0) },
                    pubDate: formatPubDate(currentPubDate),
                    duration: currentDuration.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                )
                episodes.append(episode)
                insideItem = false
            }
        }
    }

    nonisolated func parserDidEndDocument(_ parser: XMLParser) {
        MainActor.assumeIsolated {
            continuation?.resume(returning: episodes)
            continuation = nil
        }
    }

    nonisolated func parser(
        _ parser: XMLParser, parseErrorOccurred parseError: Error
    ) {
        MainActor.assumeIsolated {
            // Still return whatever episodes we managed to parse.
            continuation?.resume(returning: episodes)
            continuation = nil
        }
    }

    // MARK: - Helpers

    private func formatPubDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let date = formatter.date(from: trimmed) {
            let display = DateFormatter()
            display.dateStyle = .medium
            return display.string(from: date)
        }
        return trimmed
    }
}

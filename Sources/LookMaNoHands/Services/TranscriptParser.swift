import Foundation

/// Service for parsing various transcript file formats into TranscriptSegment arrays
@available(macOS 13.0, *)
class TranscriptParser {

    // MARK: - Public Methods

    /// Parse a Zoom-style transcript file into transcript segments
    /// - Parameter fileURL: URL of the transcript file to parse
    /// - Returns: Array of transcript segments with timing and speaker information
    /// - Throws: TranscriptParserError if parsing fails
    func parseZoomTranscript(fileURL: URL) throws -> [TranscriptSegment] {
        // Read file content
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TranscriptParserError.fileNotFound
        }

        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw TranscriptParserError.parsingFailed("Failed to read file: \(error.localizedDescription)")
        }

        guard !content.isEmpty else {
            throw TranscriptParserError.emptyContent
        }

        // Parse the content
        return try parseZoomContent(content)
    }

    // MARK: - Private Parsing Methods

    /// Parse Zoom transcript content into segments
    /// Format: [Speaker Name] HH:MM:SS on one line, text on next line(s)
    private func parseZoomContent(_ content: String) throws -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []

        // Split into lines for parsing
        let lines = content.components(separatedBy: .newlines)

        // Regex pattern for Zoom header: [Speaker Name] HH:MM:SS
        let headerPattern = #"^\[([^\]]+)\]\s+(\d{2}:\d{2}:\d{2})$"#
        let headerRegex = try NSRegularExpression(pattern: headerPattern, options: [])

        var firstTimestamp: TimeInterval?
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if line.isEmpty {
                i += 1
                continue
            }

            // Try to match header line
            let nsLine = line as NSString
            let matches = headerRegex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))

            if let match = matches.first, match.numberOfRanges == 3 {
                // Extract speaker name and timestamp
                let speakerName = nsLine.substring(with: match.range(at: 1))
                let timestampString = nsLine.substring(with: match.range(at: 2))

                // Parse timestamp (HH:MM:SS)
                guard let wallClockTime = parseWallClockTime(timestampString) else {
                    print("TranscriptParser: Warning - Invalid timestamp format: \(timestampString)")
                    i += 1
                    continue
                }

                // Set first timestamp as reference point (becomes 0.0)
                if firstTimestamp == nil {
                    firstTimestamp = wallClockTime
                }

                // Calculate relative time from first timestamp
                let relativeStartTime = wallClockTime - (firstTimestamp ?? 0)

                // Read the dialogue text from next line(s)
                i += 1
                var dialogueText = ""

                // Collect text until we hit an empty line or another header
                while i < lines.count {
                    let textLine = lines[i].trimmingCharacters(in: .whitespaces)

                    // Stop at empty line
                    if textLine.isEmpty {
                        break
                    }

                    // Stop if this looks like another header
                    let textMatches = headerRegex.matches(in: textLine, options: [], range: NSRange(location: 0, length: (textLine as NSString).length))
                    if !textMatches.isEmpty {
                        // Don't increment i - we want to process this header in the next iteration
                        break
                    }

                    // Append text (with space if we already have some)
                    if !dialogueText.isEmpty {
                        dialogueText += " "
                    }
                    dialogueText += textLine
                    i += 1
                }

                // Create segment if we have text
                if !dialogueText.isEmpty {
                    // endTime will be set to next segment's startTime, or estimated
                    let endTime = relativeStartTime + 3.0 // Default 3-second duration, will be updated

                    let segment = TranscriptSegment(
                        text: dialogueText,
                        startTime: relativeStartTime,
                        endTime: endTime,
                        timestamp: Date(),
                        audioSource: .systemAudio, // Imported transcripts are external
                        speakerLabel: speakerName
                    )

                    segments.append(segment)
                }
            } else {
                // Line doesn't match header pattern, skip it
                print("TranscriptParser: Warning - Skipping unrecognized line: \(line)")
                i += 1
            }
        }

        // Fix endTime values - set to next segment's startTime
        for i in 0..<segments.count {
            if i < segments.count - 1 {
                // Set endTime to next segment's startTime
                let nextStartTime = segments[i + 1].startTime
                segments[i] = TranscriptSegment(
                    text: segments[i].text,
                    startTime: segments[i].startTime,
                    endTime: nextStartTime,
                    timestamp: segments[i].timestamp,
                    audioSource: segments[i].audioSource,
                    speakerLabel: segments[i].speakerLabel
                )
            }
            // Last segment keeps its estimated 3-second duration
        }

        guard !segments.isEmpty else {
            throw TranscriptParserError.invalidFormat
        }

        return segments
    }

    /// Parse wall-clock time string (HH:MM:SS) into seconds since midnight
    /// - Parameter timeString: Time in format HH:MM:SS (24-hour)
    /// - Returns: Total seconds since midnight, or nil if invalid format
    private func parseWallClockTime(_ timeString: String) -> TimeInterval? {
        let components = timeString.split(separator: ":")
        guard components.count == 3 else { return nil }

        guard let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]) else {
            return nil
        }

        guard hours >= 0 && hours < 24,
              minutes >= 0 && minutes < 60,
              seconds >= 0 && seconds < 60 else {
            return nil
        }

        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    // MARK: - Format Detection (Future Enhancement)

    /// Detect transcript format from file content
    /// Currently only supports Zoom format
    func detectFormat(content: String) -> TranscriptFormat {
        // Check for Zoom pattern: [Name] HH:MM:SS
        let zoomPattern = #"^\[([^\]]+)\]\s+(\d{2}:\d{2}:\d{2})$"#
        if content.range(of: zoomPattern, options: .regularExpression) != nil {
            return .zoom
        }

        return .unknown
    }
}

// MARK: - Supporting Types

/// Supported transcript file formats
enum TranscriptFormat {
    case zoom
    case googleMeet  // Future
    case generic     // Future
    case unknown
}

/// Errors that can occur during transcript parsing
enum TranscriptParserError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case emptyContent
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Transcript file not found"
        case .invalidFormat:
            return "Unrecognized transcript format - expected Zoom format with [Speaker Name] HH:MM:SS"
        case .emptyContent:
            return "Transcript file is empty"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        }
    }
}

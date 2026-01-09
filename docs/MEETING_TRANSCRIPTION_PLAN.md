# Meeting Transcription Feature Plan

This document outlines the implementation plan for adding meeting transcription functionality to Look Ma No Hands.

## High-Level Architecture

### Two Operating Modes

1. **Dictation Mode (existing)** - Caps Lock toggle, insert text
2. **Meeting Mode (new)** - Continuous recording, structured notes output

## Technical Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| **System audio capture** | Use ScreenCaptureKit API (macOS 13+) to capture system audio loopback |
| **Long-form transcription** | Chunk audio into segments, transcribe continuously, stitch results |
| **Speaker diarization** | Use Whisper timestamps + basic analysis to detect speaker changes |
| **Structured output** | Post-process full transcript with local LLM (Ollama) to extract action items, decisions, topics |
| **File management** | Auto-save transcripts (*.txt) OR clip + Blueprint Meetings/ with timestamps |

---

## Implementation Phases

### Phase 1: System Audio Capture ✅ COMPLETED

**Files created:**
- ✅ `Sources/LookMaNoHands/Services/SystemAudioRecorder.swift`

**Tasks completed:**
- ✅ Use ScreenCaptureKit to capture system audio
- ✅ Request screen recording permission (required)
- ✅ Stream audio to ring buffer
- ✅ Audio source selection (microphone vs system audio)

**Files modified:**
- ✅ `Sources/LookMaNoHands/Models/TranscriptionState.swift`
  - Added recording source state (internal mic vs system audio)
  - Added audio source enum and state tracking

---

### Phase 2: Continuous Transcription Engine ✅ COMPLETED

**Files created:**
- ✅ `Sources/LookMaNoHands/Services/ContinuousTranscriber.swift`

**Tasks completed:**
- ✅ Maintain transcript buffer with timestamps
- ✅ Process audio in chunks with real-time transcription
- ✅ Handle silence detection to optimize processing
- ✅ Real-time status updates during transcription

---

### Phase 3: Meeting UI ✅ COMPLETED

**Files created:**
- ✅ `Sources/LookMaNoHands/Views/MeetingView.swift`

**Tasks completed:**
- ✅ Live transcript display (scrolling text)
- ✅ Timer, recording indicator
- ✅ Start/Stop controls
- ✅ Audio source picker (microphone/system audio)
- ✅ "Processing..." status for post-meeting analysis
- ✅ Prompt customization UI with jargon input
- ✅ Generated notes display

**Files modified:**
- ✅ `Sources/LookMaNoHands/App/AppDelegate.swift`
  - Added menu item: "Start Meeting Transcription"
  - Added meeting window management

---

### Phase 4: Structured Notes Generation ✅ COMPLETED

**Files created:**
- ✅ `Sources/LookMaNoHands/Services/MeetingAnalyzer.swift`

**Tasks completed:**
- ✅ Send full transcript to Ollama with specialized prompt
- ✅ Extract: Summary, Key Decisions, Action Items, Participants
- ✅ Generate markdown output
- ✅ Comprehensive default prompt template
- ✅ Customizable prompt with jargon injection

**Files modified:**
- ✅ `Sources/LookMaNoHands/Models/Settings.swift`
  - Added comprehensive default meeting prompt
  - Added meeting prompt persistence

---

### Phase 5: File Management & Export

**Files to create:**
- `Sources/LookMaNoHands/Services/MeetingExporter.swift`

**Tasks:**
- Auto-save transcripts (*.txt) OR clip + Blueprint Meetings/
- Include raw transcript + structured notes
- Support export to other formats (plain text, JSON)

**Settings/Configuration:**

New settings in SettingsView:
- Meeting save location (default: `~/Documents/LookMaNoHands/Meetings/`)
- Ollama model selection for analysis (Haiku3, mistral, mixtral, etc.)
- Auto-analysis toggle (enable vs manual review)
- Chunk size for processing (trade-off between latency vs accuracy)

---

## User Flow

1. User clicks menu bar → "Start Meeting Transcription"
2. Grant Screen Recording permission (if needed)
3. Meeting window opens, shows live transcript
4. User starts meeting (Zoom/Meet/Teams optional)
5. App processes full transcript with Ollama
6. Structured notes displayed + saved to file
7. User can review/edit/export

---

## New Dependencies Required

1. **ScreenCaptureKit** - System framework (macOS 13+)
   - Already available, no external dependency
   - Only required for structured notes, not raw transcripts

2. **Ollama integration** (existing)
   - Graceful degradation if unavailable

---

## Settings/Configuration

**New settings in SettingsView:**
- Meeting save location (default: `~/Documents/LookMaNoHands/Meetings/`)
- Ollama model selection for analysis (llama3.2:3b, mistral, mixtral, etc.)
- Auto-analysis toggle (enable vs manual review)
- Chunk size for processing (trade-off between latency vs accuracy)

**User Flow:**
1. User clicks menu bar → "Start Meeting Transcription"
2. Grant Screen Recording permission (if needed)
3. Meeting window opens, shows live transcript (optional)
4. User starts meeting (Zoom, Meet, Teams optional)
5. App processes full transcript with Ollama
6. Structured notes displayed + saved to file
7. User can review/edit/export

---

## Audio Processing

**Technical Specifications:**
- **Target audio:** 48kHz stereo → downsample to 16kHz mono
- **Chunk size:** 30-second samples (480,000 samples)
- **Overlap:** 5 seconds to prevent word clipping
- **Parallel processing:** Transcribe chunks as they arrive
- **Timestamping:** preservation: Keep Whisper's native timestamps

**Memory Management:**
- Stream transcript to disk during recording
- Limit in-memory buffer to last 10 minutes
- Clear old chunks promptly to prevent bloat

---

## Phase 6: UI Enhancements

**Risk & Mitigation:**

| Risk | Mitigation |
|------|------------|
| **High CPU usage during long meetings** | Throttle transcription to every 30s, allow "Processing in background" |
| **ScreenCaptureKit permission blocked** | Clear onboarding flow with screenshots |
| **Speaker diarization inaccuracy** | Make it optional; show timestamps for manual review |
| **Large file sizes for long meetings** | Compress audio after transcription, keep Whisper chunks compressed |

---

## Success Metrics

- ✅ Successfully capture system audio from Zoom/Meet/Teams
- ✅ Real-time continuous transcription during meetings
- ✅ Generate structured notes with Ollama integration
- ✅ Customizable prompts with domain-specific jargon
- ✅ Copy/export functionality for generated notes

---

## Future Enhancements (Post-MVP)

- Formatted notes preview and editing before export
- Speaker identification with voice profiles
- Integration with calendar (auto-detect meetings)
- Automatic meeting notes saving to disk
- Meeting history browser with search

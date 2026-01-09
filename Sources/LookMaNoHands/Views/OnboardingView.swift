import SwiftUI
import AVFoundation

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var onboardingState = OnboardingState()

    // Services (injected from AppDelegate)
    let whisperService: WhisperService
    let ollamaService: OllamaService
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicatorView(currentStep: onboardingState.currentStep)
                .padding(.top, 20)
                .padding(.bottom, 10)

            // Content area
            TabView(selection: $onboardingState.currentStep) {
                WelcomeStepView(onboardingState: onboardingState)
                    .tag(OnboardingState.Step.welcome)

                OllamaStepView(
                    onboardingState: onboardingState,
                    ollamaService: ollamaService
                )
                    .tag(OnboardingState.Step.ollama)

                WhisperModelStepView(
                    onboardingState: onboardingState,
                    whisperService: whisperService
                )
                    .tag(OnboardingState.Step.whisperModel)

                PermissionsStepView(
                    onboardingState: onboardingState
                )
                    .tag(OnboardingState.Step.permissions)

                CompletionStepView(
                    onboardingState: onboardingState
                )
                    .tag(OnboardingState.Step.complete)
            }
            .animation(.easeInOut, value: onboardingState.currentStep)

            // Navigation buttons
            OnboardingNavigationView(
                state: onboardingState,
                onComplete: completeOnboarding
            )
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .frame(width: 700, height: 550)
    }

    private func completeOnboarding() {
        Settings.shared.hasCompletedOnboarding = true
        onComplete()
        dismiss()
    }
}

// MARK: - Progress Indicator

struct ProgressIndicatorView: View {
    let currentStep: OnboardingState.Step

    var body: some View {
        HStack(spacing: 12) {
            ForEach(OnboardingState.Step.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @Bindable var onboardingState: OnboardingState

    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            // App icon
            Image(systemName: "mic.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)

            // Title
            Text("Welcome to Look Ma No Hands")
                .font(.system(size: 32, weight: .bold))

            // Description
            VStack(spacing: 12) {
                Text("Fast, local voice dictation for macOS")
                    .font(.title3)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(icon: "bolt.fill", text: "Lightning-fast voice dictation")
                    FeatureRow(icon: "lock.fill", text: "100% local - your voice never leaves your Mac")
                    FeatureRow(icon: "waveform", text: "AI-powered meeting transcription")
                }
                .padding(.top, 15)
            }

            Spacer()

            // Get Started button
            Button(action: {
                onboardingState.nextStep()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Ollama Step

struct OllamaStepView: View {
    @Bindable var onboardingState: OnboardingState
    let ollamaService: OllamaService

    @State private var ollamaInstalled: Bool = false
    @State private var isChecking: Bool = true

    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            // Icon
            Image(systemName: "brain.head.profile")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.purple)

            // Title
            Text("Install Ollama (Optional)")
                .font(.system(size: 28, weight: .bold))

            // Description
            Text("Ollama enables AI-powered meeting notes from transcripts.\nVoice dictation works without it.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            // Status
            if isChecking {
                ProgressView("Checking for Ollama...")
                    .padding()
            } else if ollamaInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ollama is installed and running")
                        .font(.headline)
                }
                .padding()
            } else {
                VStack(spacing: 15) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Installation steps:")
                            .font(.headline)

                        InstructionRow(number: 1, text: "Open Terminal")
                        InstructionRow(number: 2, text: "Run: brew install ollama")
                        InstructionRow(number: 3, text: "Run: ollama serve")
                    }
                    .frame(maxWidth: 450)

                    // Copy commands button
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("brew install ollama && ollama serve", forType: .string)
                    }) {
                        Label("Copy Commands", systemImage: "doc.on.doc")
                    }

                    // Check again button
                    Button(action: {
                        checkOllama()
                    }) {
                        Label("Check Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()

            // Skip button
            if !ollamaInstalled {
                Button("Skip for Now") {
                    onboardingState.ollamaSkipped = true
                    onboardingState.nextStep()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .onAppear {
            checkOllama()
        }
    }

    private func checkOllama() {
        isChecking = true
        Task {
            let available = await ollamaService.isAvailable()
            await MainActor.run {
                ollamaInstalled = available
                isChecking = false
            }
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Whisper Model Step

struct WhisperModelStepView: View {
    @Bindable var onboardingState: OnboardingState
    let whisperService: WhisperService

    @State private var modelExists: Bool = false
    @State private var isCheckingModel: Bool = true

    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            // Icon
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)

            // Title
            Text("Download Whisper Model")
                .font(.system(size: 28, weight: .bold))

            // Description
            Text("Required for voice transcription.\nWe recommend the Tiny model for best speed.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // Status or download UI
            if isCheckingModel {
                ProgressView("Checking for existing model...")
                    .padding()
            } else if modelExists || onboardingState.modelDownloaded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Model already installed: \(onboardingState.selectedModel.rawValue)")
                        .font(.headline)
                }
                .padding()
            } else {
                VStack(spacing: 20) {
                    // Model picker
                    Picker("Select Model", selection: $onboardingState.selectedModel) {
                        Text("Tiny (75MB) - Recommended").tag(WhisperModel.tiny)
                        Text("Base (142MB)").tag(WhisperModel.base)
                        Text("Small (466MB)").tag(WhisperModel.small)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 450)

                    // Download button or progress
                    if onboardingState.isDownloadingModel {
                        VStack(spacing: 12) {
                            ProgressView(value: onboardingState.downloadProgress, total: 1.0)
                                .frame(maxWidth: 350)

                            Text("\(Int(onboardingState.downloadProgress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            downloadModel()
                        }) {
                            Label("Download Model", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: 350)
                    }
                }
            }

            Spacer()
        }
        .padding(40)
        .onAppear {
            checkExistingModel()
        }
    }

    private func checkExistingModel() {
        isCheckingModel = true
        Task {
            // Check if any model exists
            let tinyExists = WhisperService.modelExists(named: "tiny")
            let baseExists = WhisperService.modelExists(named: "base")
            let smallExists = WhisperService.modelExists(named: "small")

            await MainActor.run {
                modelExists = tinyExists || baseExists || smallExists
                onboardingState.modelDownloaded = modelExists
                isCheckingModel = false

                // Set selected model based on what exists
                if tinyExists {
                    onboardingState.selectedModel = .tiny
                } else if baseExists {
                    onboardingState.selectedModel = .base
                } else if smallExists {
                    onboardingState.selectedModel = .small
                }
            }
        }
    }

    private func downloadModel() {
        onboardingState.isDownloadingModel = true
        onboardingState.downloadProgress = 0.0

        Task {
            do {
                try await WhisperService.downloadModel(
                    named: onboardingState.selectedModel.rawValue,
                    progress: { progress in
                        Task { @MainActor in
                            onboardingState.downloadProgress = progress
                        }
                    }
                )

                await MainActor.run {
                    onboardingState.isDownloadingModel = false
                    onboardingState.modelDownloaded = true
                    Settings.shared.whisperModel = onboardingState.selectedModel
                }
            } catch {
                await MainActor.run {
                    onboardingState.isDownloadingModel = false
                    // Show error (simplified for now)
                    print("Download error: \(error)")
                }
            }
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @Bindable var onboardingState: OnboardingState

    @State private var permissionCheckTimer: Timer?

    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            // Icon
            Image(systemName: "lock.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.orange)

            // Title
            Text("Grant Permissions")
                .font(.system(size: 28, weight: .bold))

            // Description
            Text("Look Ma No Hands needs permissions to work properly")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // Permission cards
            VStack(spacing: 15) {
                // Microphone permission
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Capture your voice for dictation",
                    isGranted: onboardingState.hasMicrophonePermission,
                    actionTitle: "Grant Permission",
                    action: {
                        requestMicrophonePermission()
                    }
                )

                // Accessibility permission
                PermissionCard(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Monitor Caps Lock and insert text into apps",
                    isGranted: onboardingState.hasAccessibilityPermission,
                    actionTitle: "Open System Settings",
                    action: {
                        openAccessibilitySettings()
                    },
                    extraInfo: onboardingState.hasAccessibilityPermission ? nil : "You'll need to manually enable accessibility in System Settings"
                )
            }
            .frame(maxWidth: 500)

            Spacer()
        }
        .padding(40)
        .onAppear {
            startPermissionChecking()
        }
        .onDisappear {
            stopPermissionChecking()
        }
    }

    private func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                onboardingState.hasMicrophonePermission = granted
            }
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func startPermissionChecking() {
        // Initial check
        checkPermissions()

        // Check every second
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkPermissions()
        }
    }

    private func stopPermissionChecking() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func checkPermissions() {
        Task {
            // Check microphone
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            let micGranted = (micStatus == .authorized)

            // Check accessibility
            let accessibilityGranted = AXIsProcessTrusted()

            await MainActor.run {
                onboardingState.hasMicrophonePermission = micGranted
                onboardingState.hasAccessibilityPermission = accessibilityGranted
            }
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void
    var extraInfo: String? = nil

    var body: some View {
        HStack(spacing: 15) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 50)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let extraInfo = extraInfo {
                    Text(extraInfo)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Status/Action
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            } else {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Completion Step

struct CompletionStepView: View {
    @Bindable var onboardingState: OnboardingState

    var needsRestart: Bool {
        onboardingState.hasAccessibilityPermission
    }

    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            // Icon
            Image(systemName: needsRestart ? "arrow.clockwise.circle.fill" : "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(needsRestart ? .orange : .green)

            // Title
            Text(needsRestart ? "Setup Complete - Restart Required" : "You're All Set!")
                .font(.system(size: 28, weight: .bold))

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration Summary:")
                    .font(.headline)
                    .padding(.bottom, 5)

                SummaryRow(
                    icon: "waveform",
                    text: "Whisper model: \(onboardingState.selectedModel.rawValue)",
                    status: .success
                )

                SummaryRow(
                    icon: "brain",
                    text: "Ollama: \(onboardingState.ollamaSkipped ? "Skipped" : "Installed")",
                    status: onboardingState.ollamaSkipped ? .warning : .success
                )

                SummaryRow(
                    icon: "mic",
                    text: "Microphone: \(onboardingState.hasMicrophonePermission ? "Granted" : "Not granted")",
                    status: onboardingState.hasMicrophonePermission ? .success : .warning
                )

                SummaryRow(
                    icon: "accessibility",
                    text: "Accessibility: \(onboardingState.hasAccessibilityPermission ? "Granted" : "Not granted")",
                    status: onboardingState.hasAccessibilityPermission ? .success : .warning
                )
            }
            .frame(maxWidth: 450)

            if needsRestart {
                Text("The app will restart to apply accessibility permissions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if !onboardingState.hasMicrophonePermission || !onboardingState.hasAccessibilityPermission {
                Text("⚠️ Some permissions were not granted.\nYou can configure them later in Settings.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding(40)
    }
}

struct SummaryRow: View {
    enum Status {
        case success
        case warning
    }

    let icon: String
    let text: String
    let status: Status

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(status == .success ? .green : .orange)
                .frame(width: 20)

            Image(systemName: icon)
                .frame(width: 20)

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Navigation View

struct OnboardingNavigationView: View {
    @Bindable var state: OnboardingState
    let onComplete: () -> Void

    var body: some View {
        HStack {
            // Back button
            Button(action: {
                state.previousStep()
            }) {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(state.currentStep == .welcome)

            Spacer()

            // Continue/Finish button
            Button(action: {
                if state.currentStep == .complete {
                    onComplete()
                } else {
                    state.nextStep()
                }
            }) {
                Text(state.currentStep == .complete ? "Finish" : "Continue")
                    .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.canContinue())
        }
    }
}

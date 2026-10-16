import SwiftUI
import AVFoundation
import Combine

// Paste this entire file into ContentView.swift.
// Keep your project's existing App file and its single @main.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Quick guidance for water, heat, and debris.")
                } header: {
                    Text("Phone First Aid")
                }

                NavigationLink {
                    WaterView()
                } label: {
                    Label("Water & Spills", systemImage: "drop.fill")
                }

                NavigationLink {
                    HeatView()
                } label: {
                    Label("Overheating", systemImage: "thermometer.sun.fill")
                }

                NavigationLink {
                    DebrisView()
                } label: {
                    Label("Dust & Debris", systemImage: "sparkles")
                }
            }
            .navigationTitle("Phone First Aid")
        }
    }
}

struct WaterView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("speakerTimeRemaining") private var timeRemaining = 60
    @State private var timerIsRunning = false
    @State private var deadline: Date?
    @State private var message = ""
    @StateObject private var audio = WaterAudioPlayer()

    // Your one-second countdown publisher.
    private let timer = Timer.publish(
        every: 1, on: .main, in: .common
    ).autoconnect()

    var body: some View {
        List {
            Section("Do this first") {
                Text("Disconnect charging cables and accessories.")
                Text("Gently tap the phone against your hand with the connector facing down. Leave it in a dry place with airflow.")
                Text("Do not use rice, heat, compressed air, or objects inside the connector.")
                Text("After liquid exposure, wait at least 5 hours before reconnecting a cable, and only reconnect when completely dry. Drying may take longer.")
                Link("Apple's liquid-exposure guidance",
                     destination: URL(string: "https://support.apple.com/108039")!)
            }

            Section {
                TimeDisplay(
                    timeRemaining: $timeRemaining,
                    timerIsRunning: timerIsRunning
                )
                .frame(maxWidth: .infinity)

                Button(timerIsRunning ? "Stop & Reset" : "Play to get water out of your phone") {
                    if timerIsRunning {
                        stop(reset: true)
                    } else {
                        start()
                    }
                }
                .buttonStyle(.borderedProminent)
                Text("Playback does not confirm that your phone is dry or safe to charge.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Reset to 60 seconds") {
                    stop(reset: true)
                }

                if !message.isEmpty {
                    Text(message).font(.footnote)
                }
            }
        }
        .navigationTitle("Water & Spills")
        .onAppear {
            // A persisted number never resumes audio automatically.
            timeRemaining = 60
        }
        .onReceive(timer) { _ in
            guard timerIsRunning, let deadline else { return }
            // Use elapsed wall time so a delayed timer does not drift.
            timeRemaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
            if timeRemaining == 0 {
                stop(reset: false)
                message = "Playback finished. This does not mean the phone is dry."
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: AVAudioSession.interruptionNotification
        )) { _ in
            stop(reset: true)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: AVAudioSession.routeChangeNotification
        )) { _ in
            if timerIsRunning {
                stop(reset: true)
                message = "Audio output changed. Playback stopped."
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: ProcessInfo.thermalStateDidChangeNotification
        )) { _ in
            let state = ProcessInfo.processInfo.thermalState
            if timerIsRunning && (state == .serious || state == .critical) {
                stop(reset: true)
                message = "Phone is too warm. Let it cool."
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stop(reset: true) }
        }
        .onDisappear { stop(reset: true) }
    }

    private func start() {
        let state = ProcessInfo.processInfo.thermalState
        guard state != .serious && state != .critical else {
            message = "Phone is too warm. Let it cool before playing audio."
            return
        }
        do {
            try audio.start()
            if timeRemaining <= 0 { timeRemaining = 60 }
            deadline = Date().addingTimeInterval(Double(timeRemaining))
            timerIsRunning = true
            message = ""
        } catch {
            stop(reset: true)
            message = error.localizedDescription
        }
    }

    private func stop(reset: Bool) {
        audio.stop()
        timerIsRunning = false
        deadline = nil
        if reset { timeRemaining = 60 }
    }
}

// @Binding lets this child update the parent's countdown.
struct TimeDisplay: View {
    @Binding var timeRemaining: Int
    let timerIsRunning: Bool

    var body: some View {
        VStack {
            Button {
                timeRemaining = min(timeRemaining + 10, 120)
            } label: {
                Text("\(timeRemaining)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .buttonStyle(.plain)
            .disabled(timerIsRunning)
            .accessibilityLabel("Time remaining: \(timeRemaining) seconds")
            Text(timerIsRunning
                 ? "seconds remaining"
                 : "Tap to add 10 seconds • maximum 120")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

@MainActor
final class WaterAudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func start() throws {
        stop()
        guard let url = Bundle.main.url(
            forResource: "waterout", withExtension: "mp3"
        ) else {
            throw NSError(domain: "WaterAudio", code: 1, userInfo: [
                NSLocalizedDescriptionKey:
                    "waterout.mp3 was not found. Add it to the app target in Xcode."
            ])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        guard session.currentRoute.outputs.count == 1,
              session.currentRoute.outputs.first?.portType == .builtInSpeaker else {
            throw NSError(domain: "WaterAudio", code: 2, userInfo: [
                NSLocalizedDescriptionKey:
                    "Select the iPhone speaker. Disconnect headphones or Bluetooth audio."
            ])
        }

        let newPlayer = try AVAudioPlayer(contentsOf: url)
        // Repeat short recordings until the countdown ends.
        newPlayer.numberOfLoops = -1
        newPlayer.volume = 0.4
        guard newPlayer.prepareToPlay(), newPlayer.play() else {
            throw NSError(domain: "WaterAudio", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Audio could not start."
            ])
        }
        player = newPlayer
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}

struct HeatView: View {
    @State private var thermalState = ProcessInfo.processInfo.thermalState

    private var status: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Slightly elevated"
        case .serious: return "High"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        List {
            Section("System thermal status") {
                Text(status).font(.title2.bold())
                Text("This is a system status, not a temperature reading or battery-health diagnosis.")
                    .font(.footnote)
            }
            Section("If a temperature warning appears") {
                Text("Turn off the phone.")
                Text("Move it to a cooler place away from direct sunlight.")
                Text("Allow it to cool before using it again.")
                Text("This app cannot actively cool your phone.")
                Link("Apple's temperature guidance",
                     destination: URL(string: "https://support.apple.com/118431")!)
            }
        }
        .navigationTitle("Overheating")
        .onAppear { thermalState = ProcessInfo.processInfo.thermalState }
        .onReceive(NotificationCenter.default.publisher(
            for: ProcessInfo.thermalStateDidChangeNotification
        )) { _ in
            thermalState = ProcessInfo.processInfo.thermalState
        }
    }
}

struct DebrisView: View {
    var body: some View {
        List {
            Section("Exterior cleaning") {
                Text("Disconnect cables and turn off the phone.")
                Text("Wipe the exterior with a soft, slightly damp, lint-free cloth.")
                Text("Keep moisture out of openings. Do not use compressed air.")
            }
            Section("Port or speaker problems") {
                Text("Do not force tools into the charging port.")
                Text("If charging or sound problems persist, seek service. Audio cannot confirm that debris has been removed.")
                Link("Apple's cleaning guidance",
                     destination: URL(string: "https://support.apple.com/108765")!)
            }
        }
        .navigationTitle("Dust & Debris")
    }
}

#Preview {
    ContentView()
}



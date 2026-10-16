import SwiftUI
import AVFoundation
import Combine
import Observation

// Paste this entire file into ContentView.swift.
// Keep your project's existing App file and its single @main.
struct ContentView: View {
    @State private var document = Document()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Quick guidance for water, heat, and debris.")
                } header: {
                    Text("Phone First Aid")
                }

                NavigationLink {
                    HistoryView()
                } label: {
                    Label("Danger History & Heatmap", systemImage: "calendar")
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
        .environment(document)
    }
}

struct WaterView: View {
    @State private var showingLog = false
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
            Section {
                Button("Log this incident") { showingLog = true }
            }

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
        .sheet(isPresented: $showingLog) {
            IncidentForm(initialKind: .water)
        }
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

// Plays waterout.mp3 from the app bundle.
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
    @State private var showingLog = false
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
            Section {
                Button("Log this incident") { showingLog = true }
            }

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
        .sheet(isPresented: $showingLog) {
            IncidentForm(initialKind: .heat)
        }
        .onAppear { thermalState = ProcessInfo.processInfo.thermalState }
        .onReceive(NotificationCenter.default.publisher(
            for: ProcessInfo.thermalStateDidChangeNotification
        )) { _ in
            thermalState = ProcessInfo.processInfo.thermalState
        }
    }
}

struct DebrisView: View {
    @State private var showingLog = false
    var body: some View {
        List {
            Section {
                Button("Log this incident") { showingLog = true }
            }

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
        .sheet(isPresented: $showingLog) {
            IncidentForm(initialKind: .sand)
        }
    }
}

// MARK: - Saved incident data

enum DangerKind: String, Codable, CaseIterable, Identifiable {
    case water, heat, sand
    var id: String { rawValue }
    var title: String {
        switch self {
        case .water: return "Water"
        case .heat: return "Heat"
        case .sand: return "Sand / Debris"
        }
    }
    var color: Color {
        switch self {
        case .water: return .blue
        case .heat: return .red
        case .sand: return Color(red: 0.65, green: 0.47, blue: 0.04)
        }
    }
}

struct DangerIncident: Identifiable, Codable {
    var id = UUID()
    var date: Date
    // Store the user's local calendar date so travel does not shift history.
    var dayKey: String
    var kind: DangerKind
    var durationSeconds: Int
}

func incidentDayKey(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
}

func durationLabel(_ seconds: Int) -> String {
    "\(seconds / 60)m \(seconds % 60)s"
}

// Same shared-model idea as your teacher's Document example.
@MainActor
@Observable
final class Document {
    private(set) var items: [DangerIncident] = []
    var selectedDate = Date()
    var status = ""
    private(set) var loadFailed = false
    private let historyFile = "dangerHistory.json"

    init() { restoreHistory() }

    private func fileURL(_ name: String) throws -> URL {
        let directory = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return directory.appendingPathComponent(name)
    }

    private func write(_ records: [DangerIncident], to name: String) throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL(name), options: .atomic)
    }

    private func read(_ name: String) throws -> [DangerIncident] {
        let data = try Data(contentsOf: fileURL(name))
        let records = try JSONDecoder().decode([DangerIncident].self, from: data)
        guard records.allSatisfy({
            $0.durationSeconds > 0 && $0.date.timeIntervalSince1970.isFinite
        }), Set(records.map(\.id)).count == records.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return records
    }

    func restoreHistory() {
        do {
            let url = try fileURL(historyFile)
            items = FileManager.default.fileExists(atPath: url.path)
                ? try read(historyFile) : []
            loadFailed = false
            status = ""
        } catch {
            loadFailed = true
            status = "Could not load history: \(error.localizedDescription). Existing files were kept."
        }
    }

    // Write first; only update the UI if the save succeeded.
    func add(date: Date, kind: DangerKind, seconds: Int) -> Bool {
        guard !loadFailed, date <= Date(), seconds > 0 else {
            status = "Choose a past date and a positive duration. Resolve any loading error first."
            return false
        }
        var updated = items
        updated.append(DangerIncident(
            date: date, dayKey: incidentDayKey(date),
            kind: kind, durationSeconds: seconds
        ))
        return commit(updated)
    }

    func remove(_ id: UUID) {
        guard !loadFailed else { return }
        _ = commit(items.filter { $0.id != id })
    }

    private func commit(_ updated: [DangerIncident]) -> Bool {
        do {
            try write(updated, to: historyFile)
            items = updated
            status = "History saved."
            return true
        } catch {
            status = "Save failed: \(error.localizedDescription)"
            return false
        }
    }

    // Explicit Save / Restore buttons use a separate backup.
    // Automatic saves continue to use dangerHistory.json.
    func save(_ name: String) {
        guard !loadFailed else { return }
        do {
            try write(items, to: name)
            status = "Backup saved."
        } catch {
            status = "Backup failed: \(error.localizedDescription)"
        }
    }

    func restore(_ name: String) {
        do {
            let restored = try read(name)
            try write(restored, to: historyFile)
            items = restored
            loadFailed = false
            status = "Backup restored."
        } catch {
            status = "Restore failed: \(error.localizedDescription). Current history was kept."
        }
    }

    func incidents(on date: Date) -> [DangerIncident] {
        items.filter { $0.dayKey == incidentDayKey(date) }
            .sorted { $0.date > $1.date }
    }

    func count(on date: Date, kind: DangerKind) -> Int {
        incidents(on: date).filter { $0.kind == kind }.count
    }
}

// MARK: - Log form

struct IncidentForm: View {
    @Environment(Document.self) private var document
    @Environment(\.dismiss) private var dismiss
    @State private var kind: DangerKind
    @State private var date = Date()
    @State private var minutes = 0
    @State private var seconds = 10

    init(initialKind: DangerKind = .water) {
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened?") {
                    Picker("Danger", selection: $kind) {
                        ForEach(DangerKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    DatePicker("Incident began", selection: $date, in: ...Date())
                }
                Section("Estimated exposure duration") {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...1440)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                    Text("Enter how long the phone was exposed. Audio playback time is not exposure time. Each record is counted on the date it began.")
                        .font(.footnote)
                }
                if !document.status.isEmpty {
                    Text(document.status).font(.footnote)
                }
            }
            .navigationTitle("Log Incident")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if document.add(date: date, kind: kind,
                                        seconds: minutes * 60 + seconds) {
                            dismiss()
                        }
                    }
                    .disabled(minutes * 60 + seconds == 0 || document.loadFailed)
                }
            }
        }
    }
}

// MARK: - Calendar heatmap

struct HistoryView: View {
    @Environment(Document.self) private var document
    @State private var month = Date()
    @State private var showingLog = false
    @State private var confirmingRestore = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private let calendar = Calendar.current

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)!.start
    }
    private var leadingDays: Int {
        (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    }
    private var days: Int {
        calendar.range(of: .day, in: .month, for: monthStart)!.count
    }
    private var weekdayLabels: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        @Bindable var document = document
        List {
            Section {
                Button("Log an incident") { showingLog = true }
                Text("Records are entered manually and saved automatically on this device.")
                    .font(.footnote)
            }
            Section("Incidents by date") {
                HStack {
                    Button { moveMonth(-1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous month")
                    Spacer()
                    Text(monthStart.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next month")
                }
                .buttonStyle(.borderless)

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdayLabels[index]).font(.caption2)
                    }
                    ForEach(0..<(leadingDays + days), id: \.self) { index in
                        if index < leadingDays {
                            Color.clear.frame(height: 60)
                        } else {
                            let date = calendar.date(
                                byAdding: .day, value: index - leadingDays,
                                to: monthStart
                            )!
                            HeatmapDay(date: date, selected: calendar.isDate(
                                date, inSameDayAs: document.selectedDate
                            )) {
                                document.selectedDate = date
                            }
                        }
                    }
                }
                ForEach(DangerKind.allCases) { kind in
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(kind.color).frame(width: 16, height: 10)
                        Text(kind.title).font(.caption)
                    }
                }
                Text("Each day has three bands: water, heat, then sand. Darker means more incidents: 1, 2, or 3+. Gray means none. Tap a day for exact counts and durations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker("Selected day", selection: $document.selectedDate,
                           displayedComponents: .date)
            }
            Section(document.selectedDate.formatted(date: .abbreviated, time: .omitted)) {
                ForEach(DangerKind.allCases) { kind in
                    let records = document.incidents(on: document.selectedDate)
                        .filter { $0.kind == kind }
                    Text("\(kind.title): \(records.count) incidents · \(durationLabel(records.reduce(0) { $0 + $1.durationSeconds }))")
                        .foregroundStyle(kind.color)
                }
                if document.incidents(on: document.selectedDate).isEmpty {
                    Text("No incidents recorded.").foregroundStyle(.secondary)
                }
                ForEach(document.incidents(on: document.selectedDate)) { incident in
                    VStack(alignment: .leading) {
                        Text(incident.kind.title).foregroundStyle(incident.kind.color)
                        Text("\(incident.date.formatted(date: .omitted, time: .shortened)) · \(durationLabel(incident.durationSeconds))")
                            .font(.caption)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            document.remove(incident.id)
                        }
                    }
                }
            }
            Section("Save & Restore") {
                Button("Save Backup") { document.save("dangerBackup.json") }
                    .disabled(document.loadFailed)
                Button("Restore Backup") { confirmingRestore = true }
                if document.loadFailed {
                    Button("Retry Loading History") { document.restoreHistory() }
                }
                Text("Restore replaces current history with your last saved backup. Records stay on this device; this is not a cloud backup.")
                    .font(.footnote)
                Text(document.status).font(.footnote)
            }
        }
        .navigationTitle("Danger History")
        .sheet(isPresented: $showingLog) { IncidentForm() }
        .confirmationDialog("Replace history with your saved backup?",
                            isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Restore Backup", role: .destructive) {
                document.restore("dangerBackup.json")
            }
        }
    }

    private func moveMonth(_ offset: Int) {
        month = calendar.date(byAdding: .month, value: offset, to: monthStart)!
    }
}

struct HeatmapDay: View {
    @Environment(Document.self) private var document
    let date: Date
    let selected: Bool
    let action: () -> Void

    private var description: String {
        let counts = DangerKind.allCases.map {
            "\($0.title): \(document.count(on: date, kind: $0))"
        }.joined(separator: ", ")
        return date.formatted(date: .complete, time: .omitted) + ", " + counts
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption2).foregroundStyle(.primary)
                ForEach(DangerKind.allCases) { kind in
                    let count = document.count(on: date, kind: kind)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(count == 0 ? Color.gray.opacity(0.15)
                              : kind.color.opacity(min(1, 0.25 + Double(count) * 0.25)))
                        .frame(height: 7)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 60)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(selected ? Color.primary : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(description)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}


#Preview {
    ContentView()
}



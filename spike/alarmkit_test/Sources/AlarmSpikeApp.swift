import SwiftUI
import AlarmKit

@main
struct AlarmSpikeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var model = SpikeModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("iOS", value: UIDevice.current.systemVersion)
                    LabeledContent("Alarm permission", value: model.authorization)
                    Text(model.signature)
                        .font(.footnote)
                }

                Section("Loudness file for the next alarm") {
                    Stepper("Level \(model.level) of 5", value: $model.level, in: 1...5)
                }

                Section("Tests") {
                    Button("1. Allow alarms") {
                        model.requestPermission()
                    }
                    Button("2. Ring in 2 min (no snooze)") {
                        model.scheduleOnce(after: 120, snoozeSeconds: nil)
                    }
                    Button("3. Ring in 2 min, snooze 1 min") {
                        model.scheduleOnce(after: 120, snoozeSeconds: 60)
                    }
                    Button("4. Ring in 2 min, snooze 9 min") {
                        model.scheduleOnce(after: 120, snoozeSeconds: 9 * 60)
                    }
                    Button("5. Daily repeat, first ring in about 3 min") {
                        model.scheduleDaily(after: 180)
                    }
                    Button("Cancel all alarms", role: .destructive) {
                        model.cancelAll()
                    }
                }

                Section("Alarms the system holds") {
                    if model.alarms.isEmpty {
                        Text("None")
                    } else {
                        ForEach(model.alarms) { alarm in
                            Text("\(alarm.id.uuidString.prefix(6))  \(String(describing: alarm.state))")
                                .font(.caption.monospaced())
                        }
                    }
                }

                Section("Log (newest first)") {
                    ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                    }
                }
            }
            .navigationTitle("Alarm Spike")
        }
    }
}

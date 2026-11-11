import SwiftUI
import UIKit
import AlarmKit
import ActivityKit
import AppIntents

/// Extra data stored with an alarm. This test needs none, so it is empty.
struct SpikeMetadata: AlarmMetadata {}

/// Everything the test screen does with AlarmKit lives here.
@MainActor
final class SpikeModel: ObservableObject {
    @Published var lines: [String] = []
    @Published var alarms: [Alarm] = []
    @Published var authorization = "unknown"
    /// Which of the five pre-scaled loudness files the next alarm uses (1 quietest, 5 loudest).
    @Published var level = 3

    let signature = SpikeModel.readSignatureLine()
    private let manager = AlarmManager.shared

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init() {
        refreshAuthorization()
        log("Started on iOS \(UIDevice.current.systemVersion)")
        Task { [weak self] in
            guard let self else { return }
            for await current in self.manager.alarmUpdates {
                self.alarms = current
                self.log("Alarms now: " + self.describe(current))
            }
        }
    }

    // MARK: Log

    func log(_ text: String) {
        let stamp = SpikeModel.timeFormatter.string(from: Date())
        lines.insert("\(stamp)  \(text)", at: 0)
        if lines.count > 80 { lines.removeLast() }
    }

    func describe(_ list: [Alarm]) -> String {
        if list.isEmpty { return "none" }
        return list
            .map { "\($0.id.uuidString.prefix(6)) \(String(describing: $0.state))" }
            .joined(separator: ", ")
    }

    // MARK: Permission

    func refreshAuthorization() {
        authorization = String(describing: manager.authorizationState)
    }

    func requestPermission() {
        Task {
            do {
                let state = try await manager.requestAuthorization()
                authorization = String(describing: state)
                log("Permission result: \(authorization)")
            } catch {
                log("Permission error: \(error)")
            }
        }
    }

    // MARK: Scheduling

    /// One-time alarm a few seconds from now. `snoozeSeconds` adds a Snooze button.
    func scheduleOnce(after seconds: TimeInterval, snoozeSeconds: TimeInterval?) {
        let fireDate = Date().addingTimeInterval(seconds)
        let label = snoozeSeconds == nil
            ? "one-time in \(Int(seconds)) s"
            : "one-time in \(Int(seconds)) s, snooze \(Int(snoozeSeconds ?? 0)) s"
        schedule(Alarm.Schedule.fixed(fireDate), snoozeSeconds: snoozeSeconds, label: label)
    }

    /// Repeating alarm: first ring a few minutes from now, then every day.
    func scheduleDaily(after seconds: TimeInterval) {
        let target = Date().addingTimeInterval(seconds)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: target)
        let time = Alarm.Schedule.Relative.Time(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        let everyDay: [Locale.Weekday] = [
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
        ]
        let relative = Alarm.Schedule.Relative(time: time, repeats: .weekly(everyDay))
        let label = "daily at \(parts.hour ?? 0):\(String(format: "%02d", parts.minute ?? 0))"
        schedule(Alarm.Schedule.relative(relative), snoozeSeconds: nil, label: label)
    }

    private func schedule(_ when: Alarm.Schedule, snoozeSeconds: TimeInterval?, label: String) {
        Task {
            do {
                let snoozeButton = AlarmButton(
                    text: "Snooze",
                    textColor: .white,
                    systemImageName: "repeat"
                )
                let alert = AlarmPresentation.Alert(
                    title: "Cat alarm test",
                    secondaryButton: snoozeSeconds == nil ? nil : snoozeButton,
                    secondaryButtonBehavior: snoozeSeconds == nil ? nil : .countdown
                )
                let presentation = AlarmPresentation(alert: alert, countdown: nil, paused: nil)
                let attributes = AlarmAttributes<SpikeMetadata>(
                    presentation: presentation,
                    metadata: nil,
                    tintColor: .blue
                )
                let countdown = snoozeSeconds.map {
                    Alarm.CountdownDuration(preAlert: nil, postAlert: $0)
                }
                let configuration = AlarmManager.AlarmConfiguration<SpikeMetadata>(
                    countdownDuration: countdown,
                    schedule: when,
                    attributes: attributes,
                    stopIntent: nil,
                    secondaryIntent: nil,
                    sound: .named("catbeep_\(level).wav")
                )
                let alarm = try await manager.schedule(id: UUID(), configuration: configuration)
                log("Scheduled \(label), level \(level), id \(alarm.id.uuidString.prefix(6))")
            } catch {
                log("Schedule error: \(error)")
            }
        }
    }

    func cancelAll() {
        let current = alarms
        for alarm in current {
            do {
                try manager.cancel(id: alarm.id)
            } catch {
                log("Cancel error: \(error)")
            }
        }
        log("Cancelled \(current.count) alarm(s)")
    }

    // MARK: Signature expiry

    /// Reads the expiry date from the signature that AltStore put on this app.
    static func readSignatureLine() -> String {
        guard
            let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
            let data = FileManager.default.contents(atPath: path)
        else {
            return "Signature: no embedded profile found"
        }
        // The file is signed, but the readable property list sits inside it as plain text.
        guard
            let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(of: Data("</plist>".utf8))
        else {
            return "Signature: profile found, but its text could not be located"
        }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard
            let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = object as? [String: Any],
            let expires = dictionary["ExpirationDate"] as? Date
        else {
            return "Signature: expiry date not readable"
        }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expires).day ?? 0
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Signature expires \(formatter.string(from: expires)) (\(days) days left)"
    }
}

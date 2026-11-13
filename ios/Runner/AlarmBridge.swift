import Flutter
import UIKit
import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents

/// Extra data stored with an alarm. Cat Clock needs none, so it is empty.
struct CatAlarmMetadata: AlarmMetadata {}

/// Connects the Dart side of the app to Apple's AlarmKit, which rings the alarm even when
/// the app is closed, the phone is locked, Silent is on, or a Focus mode is on.
///
/// The channel names and method names here must match lib/platform/ios/alarmkit_api.dart
/// and lib/platform/signature_info.dart. A test checks that they do.
final class AlarmBridge: NSObject, FlutterStreamHandler {
    private let manager = AlarmManager.shared
    private var eventSink: FlutterEventSink?
    private var watcher: Task<Void, Never>?

    func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "app.catclock/alarmkit", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
        let events = FlutterEventChannel(name: "app.catclock/alarmkit/events", binaryMessenger: messenger)
        events.setStreamHandler(self)

        let signature = FlutterMethodChannel(name: "app.catclock/signature", binaryMessenger: messenger)
        signature.setMethodCallHandler { call, result in
            if call.method == "expiresAt" {
                result(AlarmBridge.signatureExpiry())
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: Method calls

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "permission":
            result(AlarmBridge.permissionName(manager.authorizationState))

        case "requestPermission":
            Task {
                do {
                    let state = try await manager.requestAuthorization()
                    result(AlarmBridge.permissionName(state))
                } catch {
                    result(FlutterError(code: "permission", message: "\(error)", details: nil))
                }
            }

        case "schedule":
            guard
                let arguments = call.arguments as? [String: Any],
                let hour = arguments["hour"] as? Int,
                let minute = arguments["minute"] as? Int,
                let repeatDaily = arguments["repeatDaily"] as? Bool,
                let soundFile = arguments["soundFile"] as? String,
                let snoozeSeconds = arguments["snoozeSeconds"] as? Double ?? (arguments["snoozeSeconds"] as? Int).map(Double.init)
            else {
                result(FlutterError(code: "arguments", message: "Missing or wrong alarm settings", details: nil))
                return
            }
            Task {
                do {
                    try await schedule(hour: hour, minute: minute, repeatDaily: repeatDaily, soundFile: soundFile, snoozeSeconds: snoozeSeconds)
                    result(nil)
                } catch {
                    result(FlutterError(code: "schedule", message: "\(error)", details: nil))
                }
            }

        case "cancelAll":
            for alarm in currentAlarms() {
                try? manager.cancel(id: alarm.id)
            }
            result(nil)

        case "stopAll":
            for alarm in currentAlarms() where alarm.state == .alerting {
                try? manager.stop(id: alarm.id)
            }
            result(nil)

        case "snoozeAll":
            for alarm in currentAlarms() where alarm.state == .alerting {
                try? manager.countdown(id: alarm.id)
            }
            result(nil)

        case "current":
            result(currentAlarms().map { AlarmBridge.stateName($0.state) })

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func currentAlarms() -> [Alarm] {
        return (try? manager.alarms) ?? []
    }

    private func schedule(hour: Int, minute: Int, repeatDaily: Bool, soundFile: String, snoozeSeconds: Double) async throws {
        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let everyDay: [Locale.Weekday] = [
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
        ]
        let recurrence: Alarm.Schedule.Relative.Recurrence = repeatDaily ? .weekly(everyDay) : .never
        let schedule = Alarm.Schedule.relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))

        let snoozeButton = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            // From iOS 26.1 the system provides the Stop button itself.
            alert = AlarmPresentation.Alert(
                title: "Cat Clock",
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: "Cat Clock",
                stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        }
        let presentation = AlarmPresentation(alert: alert, countdown: nil, paused: nil)
        let attributes = AlarmAttributes<CatAlarmMetadata>(
            presentation: presentation,
            metadata: nil,
            tintColor: .blue
        )
        let configuration = AlarmManager.AlarmConfiguration<CatAlarmMetadata>(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds),
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .named(soundFile)
        )
        _ = try await manager.schedule(id: UUID(), configuration: configuration)
    }

    // MARK: Names the Dart side understands

    private static func permissionName(_ state: AlarmManager.AuthorizationState) -> String {
        switch state {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    private static func stateName(_ state: Alarm.State) -> String {
        switch state {
        case .scheduled: return "scheduled"
        case .countdown: return "countdown"
        case .paused: return "paused"
        case .alerting: return "alerting"
        @unknown default: return "scheduled"
        }
    }

    // MARK: Event stream: the list of alarms, each time it changes

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        watcher?.cancel()
        watcher = Task { [weak self] in
            guard let self else { return }
            for await list in self.manager.alarmUpdates {
                let names = list.map { AlarmBridge.stateName($0.state) }
                await MainActor.run { self.eventSink?(names) }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        watcher?.cancel()
        watcher = nil
        eventSink = nil
        return nil
    }

    // MARK: Signature expiry

    /// When the signature on this app expires, as seconds since 1970, or nil if it cannot be
    /// read. Apps installed with a free Apple ID stop opening after 7 days.
    private static func signatureExpiry() -> Double? {
        guard
            let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
            let data = FileManager.default.contents(atPath: path),
            let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(of: Data("</plist>".utf8))
        else {
            return nil
        }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard
            let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = object as? [String: Any],
            let expires = dictionary["ExpirationDate"] as? Date
        else {
            return nil
        }
        return expires.timeIntervalSince1970
    }
}

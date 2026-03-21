import Foundation
import SwiftUI

protocol NotificationScheduler {
    func requestAuthorization()
    func schedule(id: String, at date: Date, title: String, body: String)
    func cancel(ids: [String])
}

final class NoopNotificationScheduler: NotificationScheduler {
    func requestAuthorization() { }
    func schedule(id: String, at date: Date, title: String, body: String) { }
    func cancel(ids: [String]) { }
}

struct NotificationSchedulerProvider {
    let scheduler: NotificationScheduler
}

private struct NotificationSchedulerKey: EnvironmentKey {
    static let defaultValue = NotificationSchedulerProvider(scheduler: NoopNotificationScheduler())
}

extension EnvironmentValues {
    var notificationScheduler: NotificationSchedulerProvider {
        get { self[NotificationSchedulerKey.self] }
        set { self[NotificationSchedulerKey.self] = newValue }
    }
}

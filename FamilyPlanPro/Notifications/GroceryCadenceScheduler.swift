import Foundation

final class GroceryCadenceScheduler {
    private let scheduler: NotificationScheduler
    private let calendar: Calendar
    private let now: () -> Date

    init(scheduler: NotificationScheduler,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
    }

    func scheduleNudges(weekStart: Date, weekId: String) {
        let sunday = calendar.startOfDay(for: weekStart)
        let thursday = calendar.date(byAdding: .day, value: 4, to: sunday)
        let currentDate = now()
        scheduler.requestAuthorization()
        cancelNudges(weekId: weekId)
        if let sundayTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: sunday),
           sundayTime >= currentDate {
            scheduler.schedule(id: "grocery-\(weekId)-sun", at: sundayTime, title: "Grocery run", body: "Your list is ready for Sunday")
        }
        if let thursday, let thursdayTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: thursday),
           thursdayTime >= currentDate {
            scheduler.schedule(id: "grocery-\(weekId)-thu", at: thursdayTime, title: "Grocery run", body: "Your list is ready for Thursday")
        }
    }

    func cancelNudges(weekId: String) {
        scheduler.cancel(ids: ["grocery-\(weekId)-sun", "grocery-\(weekId)-thu"])
    }
}

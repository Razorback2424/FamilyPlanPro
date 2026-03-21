import Foundation

final class GroceryCadenceScheduler {
    private let scheduler: NotificationScheduler

    init(scheduler: NotificationScheduler) {
        self.scheduler = scheduler
    }

    func scheduleNudges(weekStart: Date, listId: String) {
        let calendar = Calendar.current
        let sunday = calendar.startOfDay(for: weekStart)
        let thursday = calendar.date(byAdding: .day, value: 4, to: sunday)
        scheduler.requestAuthorization()
        cancelNudges(listId: listId)
        if let sundayTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: sunday),
           sundayTime >= Date() {
            scheduler.schedule(id: "grocery-\(listId)-sun", at: sundayTime, title: "Grocery run", body: "Your list is ready for Sunday")
        }
        if let thursday, let thursdayTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: thursday),
           thursdayTime >= Date() {
            scheduler.schedule(id: "grocery-\(listId)-thu", at: thursdayTime, title: "Grocery run", body: "Your list is ready for Thursday")
        }
    }

    func cancelNudges(listId: String) {
        scheduler.cancel(ids: ["grocery-\(listId)-sun", "grocery-\(listId)-thu"])
    }
}

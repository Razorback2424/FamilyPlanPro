import Foundation
import SwiftData

enum PlanStatus: String, Codable {
    case suggestionMode
    case reviewMode
    case conflict
    case finalized
}

enum DayOfWeek: Int, Codable, CaseIterable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var localizedName: String {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.weekdaySymbols
        let index = max(0, min(weekdaySymbols.count - 1, rawValue - 1))
        return weekdaySymbols[index]
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner

    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class Family {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var members: [User] = []
    @Relationship(deleteRule: .cascade) var weeklyPlans: [WeeklyPlan] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

@Model
final class User {
    var id: UUID
    var name: String
    weak var family: Family?

    init(id: UUID = UUID(), name: String, family: Family? = nil) {
        self.id = id
        self.name = name
        self.family = family
    }
}

@Model
final class WeeklyPlan {
    var id: UUID
    var startDate: Date
    var status: PlanStatus
    var lastModifiedByUserID: UUID?
    weak var family: Family?
    @Relationship(deleteRule: .cascade) var mealSlots: [MealSlot] = []

    init(id: UUID = UUID(),
         startDate: Date,
         status: PlanStatus = .suggestionMode,
         lastModifiedByUserID: UUID? = nil,
         family: Family? = nil) {
        self.id = id
        self.startDate = startDate
        self.status = status
        self.lastModifiedByUserID = lastModifiedByUserID
        self.family = family
    }
}

@Model
final class MealSlot {
    var id: UUID
    var dayOfWeek: DayOfWeek
    var mealType: MealType
    weak var plan: WeeklyPlan?
    @Relationship(deleteRule: .cascade) var finalizedSuggestion: MealSuggestion?
    @Relationship(deleteRule: .cascade) var pendingSuggestion: MealSuggestion?

    init(id: UUID = UUID(),
         dayOfWeek: DayOfWeek,
         mealType: MealType,
         plan: WeeklyPlan? = nil) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.mealType = mealType
        self.plan = plan
    }
}

@Model
final class MealSuggestion {
    var id: UUID
    var mealName: String
    var responsibleUserID: UUID?
    var authorUserID: UUID?
    var reasonForChange: String?
    weak var slot: MealSlot?

    init(id: UUID = UUID(),
         mealName: String,
         responsibleUserID: UUID? = nil,
         authorUserID: UUID? = nil,
         reasonForChange: String? = nil,
         slot: MealSlot? = nil) {
        self.id = id
        self.mealName = mealName
        self.responsibleUserID = responsibleUserID
        self.authorUserID = authorUserID
        self.reasonForChange = reasonForChange
        self.slot = slot
    }
}


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
    var defaultOwnershipRulesJSON: String?
    @Relationship(deleteRule: .cascade) var members: [User] = []
    @Relationship(deleteRule: .cascade) var weeklyPlans: [WeeklyPlan] = []

    init(id: UUID = UUID(), name: String, defaultOwnershipRules: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.defaultOwnershipRulesJSON = Family.encodeRules(defaultOwnershipRules)
    }

    var users: [User] {
        get { members }
        set { members = newValue }
    }

    var plans: [WeeklyPlan] {
        get { weeklyPlans }
        set { weeklyPlans = newValue }
    }

    var defaultOwnershipRules: [String: String] {
        get { Family.decodeRules(defaultOwnershipRulesJSON) }
        set { defaultOwnershipRulesJSON = Family.encodeRules(newValue) }
    }

    private static func encodeRules(_ rules: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(rules),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func decodeRules(_ json: String?) -> [String: String] {
        guard let json,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
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
final class OwnershipRulesSnap {
    var rulesJSON: String
    var fridaySimple: Bool
    weak var family: Family?
    weak var plan: WeeklyPlan?

    init(rules: [String: String] = [:],
         fridaySimple: Bool = true,
         family: Family? = nil,
         plan: WeeklyPlan? = nil) {
        self.rulesJSON = OwnershipRulesSnap.encodeRules(rules)
        self.fridaySimple = fridaySimple
        self.family = family
        self.plan = plan
    }

    var rules: [String: String] {
        get { OwnershipRulesSnap.decodeRules(rulesJSON) }
        set { rulesJSON = OwnershipRulesSnap.encodeRules(newValue) }
    }

    private static func encodeRules(_ rules: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(rules),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func decodeRules(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

@Model
final class WeeklyPlan {
    var id: UUID
    var startDate: Date
    var status: PlanStatus
    var lastModifiedByUserID: UUID?
    var reviewInitiatorUserID: UUID?
    weak var family: Family?
    @Relationship(deleteRule: .cascade) var slots: [MealSlot] = []
    @Relationship(deleteRule: .cascade) var ownershipRulesSnap: OwnershipRulesSnap?
    @Relationship(deleteRule: .cascade) var groceryList: GroceryList?
    var budgetTargetCents: Int
    var budgetStatus: BudgetStatus

    init(id: UUID = UUID(),
         startDate: Date,
         status: PlanStatus = .suggestionMode,
         lastModifiedByUserID: UUID? = nil,
         reviewInitiatorUserID: UUID? = nil,
         family: Family? = nil) {
        self.id = id
        self.startDate = startDate
        self.status = status
        self.lastModifiedByUserID = lastModifiedByUserID
        self.reviewInitiatorUserID = reviewInitiatorUserID
        self.family = family
        self.budgetTargetCents = 0
        self.budgetStatus = .unset
    }

    var mealSlots: [MealSlot] {
        get { slots }
        set { slots = newValue }
    }
}

enum BudgetStatus: String, Codable {
    case unset
    case under
    case on
    case over
}

@Model
final class MealSlot {
    var id: UUID
    var date: Date
    var mealType: MealType
    var isSimple: Bool
    weak var owner: User?
    weak var plan: WeeklyPlan?
    @Relationship(deleteRule: .cascade) var finalizedSuggestion: MealSuggestion?
    @Relationship(deleteRule: .cascade) var pendingSuggestion: MealSuggestion?

    init(id: UUID = UUID(),
         date: Date,
         mealType: MealType,
         isSimple: Bool = false,
         owner: User? = nil,
         plan: WeeklyPlan? = nil) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.isSimple = isSimple
        self.owner = owner
        self.plan = plan
    }

    var dayOfWeek: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: date)
        return DayOfWeek(rawValue: weekday) ?? .monday
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

    var title: String {
        get { mealName }
        set { mealName = newValue }
    }
}

@Model
final class GroceryList {
    enum Status: String, Codable {
        case draft
        case ready
        case ordered
    }

    var id: UUID
    var status: Status
    var budgetObservedCents: Int
    weak var plan: WeeklyPlan?
    @Relationship(deleteRule: .cascade) var items: [GroceryItem] = []

    init(id: UUID = UUID(),
         status: Status = .draft,
         budgetObservedCents: Int = 0,
         plan: WeeklyPlan? = nil) {
        self.id = id
        self.status = status
        self.budgetObservedCents = budgetObservedCents
        self.plan = plan
    }
}

@Model
final class GroceryItem {
    var name: String
    var dayRef: Date?
    var checked: Bool
    weak var list: GroceryList?

    init(name: String,
         dayRef: Date? = nil,
         checked: Bool = false,
         list: GroceryList? = nil) {
        self.name = name
        self.dayRef = dayRef
        self.checked = checked
        self.list = list
    }
}

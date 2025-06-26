AGENTS.MD: Collaborative Weekly Meal Planner (SwiftUI)This document provides the governing instructions for any AI agent contributing to this project. Adherence to these rules is mandatory for all code generation, refactoring, and verification tasks.1. Environment & ToolchainIDE: All development must be done using the latest stable version of Xcode.Language: The project uses Swift 5.10 or later.Frameworks:The UI is built exclusively with SwiftUI.Data persistence and CloudKit synchronization are managed by SwiftData.Dependencies: No external dependencies are required for the MVP. Do not add any packages via Swift Package Manager without explicit instruction.2. Architectural OverviewThis app follows a clean, state-driven architecture. The core principle is a strict separation of concerns between Data Models, Views, and Workflow Logic.2.1. SwiftData ModelsThe data layer is the single source of truth. All application state is derived from these models.// Represents the shared "family" unit. This is the root object for CloudKit sharing.
@Model final class Family { ... }

// Represents a user within the family.
@Model final class User { ... }

// Central model driving the state for a given week's plan.
@Model final class WeeklyPlan {
    var status: PlanStatus // CRITICAL: This enum drives the entire UI.
    var lastModifiedByUserID: String // CRITICAL: Determines who is in "review" mode.
}

// A single meal slot for a day (e.g., Monday Dinner).
@Model final class MealSlot {
    var finalizedSuggestion: MealSuggestion?
    var pendingSuggestion: MealSuggestion? // Temporary suggestion under review.
}

// A specific meal suggestion.
@Model final class MealSuggestion { ... }

// State machine enum.
enum PlanStatus {
    case suggestionMode
    case reviewMode
    case conflict
    case finalized
}
Agent's Task: When creating or modifying data models, strictly adhere to the structures defined in the project's conceptual architecture document. Use @Model for all top-level classes intended for persistence. Use @Relationship to define ownership and deletion rules, specifically a .cascade rule from WeeklyPlan to its MealSlots.2.2. View HierarchyThe UI is composed of simple, reusable SwiftUI views that react to changes in the SwiftData models.WeeklyPlannerContainerView: This is the primary "router" view. It observes the WeeklyPlan for the current week and, based on the status and lastModifiedByUserID, it displays the correct child view. It contains all conditional logic for view presentation.SuggestionView: Shown when status == .suggestionMode. Allows the user to input initial meal ideas into MealSlot views.ReviewView: Shown when status == .reviewMode. Allows the second user to accept or reject pendingSuggestions.FinalizedView: A read-only view shown when status == .finalized.MealSlotView: A reusable component that adapts its appearance and functionality based on the current PlanStatus. DO NOT create separate views for a meal slot in suggestion vs. review mode; use conditional logic within a single view to promote reusability (DRY).3. Coding Standards & Best PracticesApple Human Interface Guidelines (HIG): All UI must conform to the HIG. Use standard SwiftUI components like List, VStack, HStack, Button, TextField, and Picker.Immutability and State: Views should be as stateless as possible. Drive all UI changes from the state of the SwiftData models. Do not introduce extraneous @State variables for data that is already modeled in SwiftData.Clarity over Brevity: Use descriptive variable and function names.Error Handling: Implement robust error handling for CloudKit operations, including sharing invitations and data synchronization.4. Core Workflow Logic (State Machine)This is the most critical section. The agent must implement the state transition logic precisely as described.Initiation: When a new WeeklyPlan is created, its status MUST be set to .suggestionMode.Submission for Review: When the first user completes their suggestions, a "Submit" button MUST transition the WeeklyPlan.status to .reviewMode and record their ID in lastModifiedByUserID.Review Process: The second user is presented with the ReviewView.On Accept: The pendingSuggestion is moved to finalizedSuggestion, and pendingSuggestion is set to nil.On Reject: The user provides a new MealSuggestion, which overwrites the existing pendingSuggestion. The WeeklyPlan.lastModifiedByUserID MUST be updated to the second user's ID. The status remains .reviewMode.Finalization: If all suggestions are accepted, the WeeklyPlan.status MUST be transitioned to .finalized. A push notification should be sent to the other user.Conflict Resolution: If User A rejects a change made by User B, the WeeklyPlan.status MUST be set to .conflict. The UI for the contested MealSlot must then present a prompt for both users to discuss and resolve the entry.5. Testing & VerificationAll logic must be verifiable. The agent is required to write tests for its changes.Unit Tests (XCTest):For any modifications to the workflow logic, create unit tests that verify the state transitions of the WeeklyPlan.status.Create a test case for each state transition: suggestion -> review, review -> review (counter-review), review -> finalized, and review -> conflict.UI Tests (XCTest):Write UI tests to confirm that the WeeklyPlannerContainerView displays the correct child view (SuggestionView, ReviewView, FinalizedView) for each PlanStatus.Mandatory Check: Before finalizing any task, execute all tests within Xcode. The agent must iterate on its changes until all existing and new tests pass.

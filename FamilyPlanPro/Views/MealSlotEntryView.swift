import SwiftUI
import SwiftData

struct MealSlotEntryView: View {
    private static let simpleFridayTemplates = [
        "Leftovers",
        "Breakfast for Dinner",
        "Takeout",
        "Pasta"
    ]

    @Environment(\.featureFlags) private var featureFlags
    let slot: MealSlot
    var members: [User]
    @Binding var mealName: String
    @Binding var responsibleSelection: ResponsibleSelection
    var onClearSuggestion: (() -> Void)?
    @State private var draftMealName: String
    @State private var showingTemplateOptions = false
    @State private var showingResponsibleOptions = false
    @FocusState private var isMealNameFocused: Bool

    init(slot: MealSlot,
         members: [User],
         mealName: Binding<String>,
         responsibleSelection: Binding<ResponsibleSelection>,
         onClearSuggestion: (() -> Void)? = nil) {
        self.slot = slot
        self.members = members
        self._mealName = mealName
        self._responsibleSelection = responsibleSelection
        self.onClearSuggestion = onClearSuggestion
        self._draftMealName = State(initialValue: mealName.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if featureFlags.mealsOwnershipRules, slot.isSimple {
                Text("Simple Friday")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Meal name", text: $draftMealName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textContentType(.none)
                .submitLabel(.done)
                .focused($isMealNameFocused)
                .onSubmit(commitDraft)
                .onChange(of: isMealNameFocused) { _, isFocused in
                    if !isFocused {
                        commitDraft()
                    }
                }
                .onChange(of: mealName) { _, newValue in
                    if !isMealNameFocused {
                        draftMealName = newValue
                    }
                }

            if featureFlags.mealsOwnershipRules, slot.isSimple {
                Button("Use Simple Friday Template") {
                    showingTemplateOptions = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("simple-friday-template-\(slot.id.uuidString)")
            }

            HStack {
                Text("Responsible")
                Spacer()
                Button(responsibleLabel) {
                    showingResponsibleOptions = true
                }
                .buttonStyle(.bordered)
            }

            if let onClearSuggestion,
               slot.pendingSuggestion != nil {
                Button("Clear Meal") {
                    onClearSuggestion()
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityIdentifier("slot-entry-\(slot.id.uuidString)")
        .confirmationDialog("Choose a Simple Friday Template",
                            isPresented: $showingTemplateOptions,
                            titleVisibility: .visible) {
            ForEach(Self.simpleFridayTemplates, id: \.self) { template in
                Button(template) {
                    mealName = template
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Assign a Responsible Person",
                            isPresented: $showingResponsibleOptions,
                            titleVisibility: .visible) {
            Button("Unassigned") {
                responsibleSelection = .unassigned
            }
            ForEach(members) { user in
                Button(user.name) {
                    responsibleSelection = .user(user.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var responsibleLabel: String {
        switch responsibleSelection {
        case .unassigned:
            return "Unassigned"
        case .user(let id):
            return members.first(where: { $0.id == id })?.name ?? "Unassigned"
        }
    }

    private func commitDraft() {
        mealName = draftMealName
    }
}

struct MealSlotEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            OwnershipRulesSnap.self,
            MealSlot.self,
            MealSuggestion.self,
            GroceryList.self,
            GroceryItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Preview")
        _ = manager.addUser(name: "Alice", to: family)
        let plan = manager.createCurrentWeekPlan(for: family)
        let slot = plan.slots.first!
        try? container.mainContext.save()

        struct PreviewWrapper: View {
            @State var mealName: String = ""
            @State var responsibleSelection: ResponsibleSelection = .unassigned
            var slot: MealSlot
            var members: [User]

            var body: some View {
                MealSlotEntryView(slot: slot,
                                  members: members,
                                  mealName: $mealName,
                                  responsibleSelection: $responsibleSelection)
            }
        }

        return PreviewWrapper(slot: slot, members: family.members)
            .modelContainer(container)
    }
}

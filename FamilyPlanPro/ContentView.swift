//
//  ContentView.swift
//  FamilyPlanPro
//
//  Created by Sean Keller on 6/25/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var families: [Family]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(families) { family in
                    NavigationLink {
                        FamilyDetailView(family: family)
                    } label: {
                        Text(family.name)
                    }
                }
                .onDelete(perform: deleteFamilies)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addSampleData) {
                        Label("Add Sample", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a family")
        }
    }

    private func addSampleData() {
        withAnimation { createDummyData(context: modelContext) }
    }

    private func deleteFamilies(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(families[index])
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: Family.self, inMemory: true)
    }
}

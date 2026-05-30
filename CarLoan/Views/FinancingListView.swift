import SwiftUI
import SwiftData

struct FinancingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Financing.createdAt, order: .reverse) private var financings: [Financing]
    @State private var showAdd = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if financings.isEmpty {
                    ContentUnavailableView(
                        String(localized: "financing.empty.title"),
                        systemImage: "car.fill",
                        description: Text(String(localized: "financing.empty.description"))
                    )
                } else {
                    List {
                        ForEach(financings) { financing in
                            NavigationLink(value: financing) {
                                FinancingRowView(financing: financing)
                            }
                        }
                        .onDelete(perform: deleteFinancings)
                    }
                }
            }
            .navigationTitle(String(localized: "financing.list.title"))
            .navigationDestination(for: Financing.self) { financing in
                DashboardView(financing: financing)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddFinancingView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func deleteFinancings(at offsets: IndexSet) {
        for index in offsets {
            context.delete(financings[index])
        }
        try? context.save()
    }
}

private struct FinancingRowView: View {
    let financing: Financing

    private var paid: Int { financing.installments.filter { $0.payment != nil }.count }
    private var progress: Double {
        guard financing.totalInstallments > 0 else { return 0 }
        return Double(paid) / Double(financing.totalInstallments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(financing.carName)
                .font(.headline)
            Text(financing.bank)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
                .tint(.blue)
            Text("\(paid)/\(financing.totalInstallments) \(String(localized: "financing.row.installments"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

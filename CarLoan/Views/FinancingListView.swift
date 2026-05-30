import SwiftUI
import SwiftData

struct FinancingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Financing.createdAt, order: .reverse) private var financings: [Financing]

    enum ActiveSheet: Identifiable {
        case add, settings, share(URL)
        var id: String {
            switch self {
            case .add: return "add"
            case .settings: return "settings"
            case .share(let url): return "share-\(url)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?
    @State private var showImportPicker = false
    @State private var showError = false
    @State private var errorMsg = ""

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
                            .swipeActions(edge: .leading) {
                                Button {
                                    exportFinancing(financing)
                                } label: {
                                    Label(String(localized: "action.export"), systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
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
                    Button { activeSheet = .add } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { activeSheet = .settings } label: {
                            Label(String(localized: "settings.title"), systemImage: "gear")
                        }
                        Button { showImportPicker = true } label: {
                            Label(String(localized: "action.import"), systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            // Single sheet for all presentations
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    AddFinancingView()
                case .settings:
                    SettingsView()
                case .share(let url):
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    importFinancing(from: url)
                case .failure(let err):
                    errorMsg = err.localizedDescription
                    showError = true
                }
            }
            .alert(String(localized: "settings.error"), isPresented: $showError) {
                Button(String(localized: "action.ok")) {}
            } message: {
                Text(errorMsg)
            }
        }
    }

    private func exportFinancing(_ financing: Financing) {
        let safeName = financing.carName.replacingOccurrences(of: " ", with: "-")
        guard let data = try? BackupService.export(financings: [financing]) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-carloan.json")
        Task {
            await Task.detached(priority: .userInitiated) {
                try? data.write(to: url)
            }.value
            activeSheet = .share(url)
        }
    }

    private func importFinancing(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            try BackupService.importBackup(data: data, context: context)
        } catch {
            errorMsg = error.localizedDescription
            showError = true
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
    private var carPhoto: UIImage? {
        financing.carPhotoFilename.flatMap { ImageStorageService.load(filename: $0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let photo = carPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: "car.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(financing.carName).font(.headline)
                    if !financing.licensePlate.isEmpty {
                        Text(financing.licensePlate)
                            .font(.caption.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.secondary)
                    }
                }
                if !financing.bank.isEmpty {
                    Text(financing.bank).font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: progress).tint(.blue)
                Text("\(paid)/\(financing.totalInstallments) \(String(localized: "financing.row.installments"))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

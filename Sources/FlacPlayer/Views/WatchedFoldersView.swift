import FlacPlayerCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct WatchedFoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchedFolder.dateAdded) private var folders: [WatchedFolder]
    @State private var watchers: [String: FolderWatcher] = [:]
    @State private var isImporting = false
    @State private var scanError: String?

    var body: some View {
        List {
            ForEach(folders) { folder in
                Label {
                    Text(folder.path)
                } icon: {
                    SidebarIconBadge(systemName: "folder.fill", color: .blue)
                }
            }
            .onDelete(perform: removeFolders)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isImporting = true
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .labelStyle(.iconOnly)
                .help("Add Folder…")
            }
        }
        .navigationTitle("")
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                addFolder(url)
            }
        }
        .onAppear {
            scanAllFolders()
            startWatchers()
        }
        .alert("Couldn't scan folder", isPresented: Binding(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Button("OK") { scanError = nil }
        } message: {
            Text(scanError ?? "")
        }
    }

    private func addFolder(_ url: URL) {
        let folder = WatchedFolder(path: url.path)
        modelContext.insert(folder)
        try? modelContext.save()
        scanFolder(url)
        startWatcher(forPath: url.path)
    }

    private func removeFolders(at offsets: IndexSet) {
        for index in offsets {
            let folder = folders[index]
            watchers[folder.path]?.stop()
            watchers[folder.path] = nil
            modelContext.delete(folder)
        }
        try? modelContext.save()
    }

    private func scanAllFolders() {
        for folder in folders {
            scanFolder(URL(fileURLWithPath: folder.path))
        }
    }

    private func scanFolder(_ url: URL) {
        do {
            try LibraryScanner.scan(folder: url, context: modelContext)
        } catch {
            scanError = "\(error)"
        }
    }

    private func startWatchers() {
        for folder in folders {
            startWatcher(forPath: folder.path)
        }
    }

    private func startWatcher(forPath path: String) {
        guard watchers[path] == nil else { return }
        let watcher = FolderWatcher(paths: [path]) {
            Task { @MainActor in
                scanFolder(URL(fileURLWithPath: path))
            }
        }
        watcher.start()
        watchers[path] = watcher
    }
}

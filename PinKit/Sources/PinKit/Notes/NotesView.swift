import SwiftUI
import SwiftData

struct NotesView: View {
    
    @Environment(NavigationStore.self)
    private var navigation

    @Environment(\.database)
    private var database
    
    @Environment(HumaneCenterService.self)
    private var service

    @State
    private var isLoading = false
    
    @State
    private var isFirstLoad = true
    
    @State
    private var query = ""
    
    @State
    private var filter = _Note.all()

    var body: some View {
        @Bindable var navigationStore = navigation
        NavigationStack(path: $navigationStore.notesNavigationPath) {
            SearchableNotesListView(
                filter: filter,
                isLoading: isLoading,
                isFirstLoad: isFirstLoad
            )
            .refreshable(action: initial)
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("New Note", systemImage: "plus") {
                        Button("Create", systemImage: "note.text.badge.plus", intent: OpenNewNoteIntent())
                        Button("Import", systemImage: "square.and.arrow.down", intent: OpenFileImportIntent())
                    } primaryAction: {
                        self.navigation.activeNote = .create()
                    }
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                        Toggle("All Items", systemImage: "note.text", isOn: .constant(true))
                        Section {
                            Button("Favorites", systemImage: "heart") {
                                
                            }
                        }
                        .disabled(true)
                    }
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Toggle("Created At", isOn: .constant(true))
                        Button("Last Modified At") {
                            
                        }
                        .disabled(true)
                    }
                }
            }
            .navigationTitle("Notes")
        }
        .sheet(item: $navigationStore.activeNote) { note in
            NoteComposerView(note: note)
        }
        .fileImporter(
            isPresented: $navigationStore.fileImporterPresented,
            allowedContentTypes: [.plainText]
        ) { result in
            Task.detached {
                do {
                    switch result {
                    case let .success(success):
                        let str = try String(contentsOf: success)
                        self.navigation.activeNote = .init(text: str, title: success.lastPathComponent)
                    case let .failure(failure):
                        break
                    }
                } catch {
                    print(error)
                }
            }
        }
        .task(initial)
        .task(id: query) {
            do {
                try await Task.sleep(for: .milliseconds(300))
                let intent = SearchNotesIntent()
                intent.query = query
                intent.service = service
                guard !query.isEmpty, let result = try await intent.perform().value else {
                    filter = _Note.all()
                    return
                }
                let ids = result.map(\.id)
                let predicate = #Predicate<_Note> {
                    ids.contains($0.parentUUID)
                }
                filter = FetchDescriptor(predicate: predicate)
            } catch is CancellationError {
                
            } catch {
                filter = _Note.all()
                print(error)
            }
        }
    }
    
    func initial() async {
        isLoading = true
        do {
            let intent = SyncNotesIntent()
            intent.database = database
            intent.service = service
            try await intent.perform()
        } catch {
            print(error)
        }
        isLoading = false
        isFirstLoad = false
    }
}

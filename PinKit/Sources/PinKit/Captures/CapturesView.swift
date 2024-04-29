import SwiftUI

struct CapturesView: View {
    
    struct ViewState {
        var isLoading = false
        var captures: [Capture] = []
    }
    
    @State
    private var state = ViewState()
    
    @Environment(HumaneCenterService.self)
    private var api
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(state.captures, id: \.uuid) { capture in
                    Section {
                        AsyncImage(url: URL(string: "https://webapi.prod.humane.cloud/capture/memory/\(capture.uuid)/file/\(capture.data.thumbnail!.fileUUID)")?.appending(queryItems: [
                            .init(name: "token", value: capture.data.thumbnail!.accessToken),
                            .init(name: "w", value: "640"),
                            .init(name: "q", value: "100")
                        ])) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            Rectangle()
                                .fill(.bar)
                                .aspectRatio(1.333, contentMode: .fit)
                                .overlay {
                                    ProgressView()
                                }
                        }
                        .listRowInsets(.init())
                        .contextMenu {
                            // TODO: video handling
                            Button("Copy Photo", systemImage: "doc.on.doc") {
                                Task {
                                    try await UIPasteboard.general.image = image(for: capture)
                                }
                            }
                            Button("Save Photo", systemImage: "square.and.arrow.down") {
                                Task {
                                    try await save(capture: capture)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: .constant(""))
            .refreshable {
                await load()
            }
            .listSectionSpacing(15)
            .navigationTitle("Captures")
        }
        .overlay {
            if !state.isLoading, state.captures.isEmpty {
                ContentUnavailableView("No captures yet", systemImage: "camera.aperture")
            }
        }
        .task {
            state.isLoading = true
            while !Task.isCancelled {
                await load()
                state.isLoading = false
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }
    
    func load() async {
        do {
            let captures = try await api.captures(100)
            withAnimation {
                state.captures = captures.content
            }
        } catch {
            print(error)
        }
    }
    
    func save(capture: Capture) async throws {
        try await UIImageWriteToSavedPhotosAlbum(image(for: capture), nil, nil, nil)
    }
    
    func image(for capture: Capture) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://webapi.prod.humane.cloud/capture/memory/\(capture.uuid)/file/\(capture.data.thumbnail!.fileUUID)")!.appending(queryItems: [
            .init(name: "token", value: capture.data.thumbnail!.accessToken),
            .init(name: "w", value: "640"),
            .init(name: "q", value: "100")
        ]))
        guard let image = UIImage(data: data) else {
            fatalError()
        }
        return image
    }
}

#Preview {
    CapturesView()
        .environment(HumaneCenterService.live())
}

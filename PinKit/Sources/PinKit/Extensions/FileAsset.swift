import Foundation
import Models

extension FileAsset {
    public func downloadUrl(memoryUUID: UUID) -> URL? {
        URL(string: "https://webapi.prod.humane.cloud/capture/memory/\(memoryUUID)/file/\(fileUUID)/download")?.appending(queryItems: [
            .init(name: "token", value: accessToken),
            .init(name: "rawData", value: "false")
        ])
    }
}

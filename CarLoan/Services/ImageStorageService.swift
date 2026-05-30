import UIKit

enum ImageStorageService {
    private static var receiptsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ image: UIImage, filename: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw ImageStorageError.compressionFailed
        }
        try data.write(to: receiptsDirectory.appendingPathComponent(filename))
    }

    static func load(filename: String) -> UIImage? {
        let url = receiptsDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: receiptsDirectory.appendingPathComponent(filename))
    }

    static func loadBase64(filename: String) -> String? {
        let url = receiptsDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return data.base64EncodedString()
    }

    static func saveFromBase64(_ base64: String, filename: String) throws {
        guard let data = Data(base64Encoded: base64) else {
            throw ImageStorageError.invalidBase64
        }
        try data.write(to: receiptsDirectory.appendingPathComponent(filename))
    }

    static func newFilename() -> String {
        UUID().uuidString + ".jpg"
    }
}

enum ImageStorageError: Error {
    case compressionFailed
    case invalidBase64
}

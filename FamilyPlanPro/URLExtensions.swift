import Foundation

extension URL {
    /// Returns the application's support directory, falling back to the documents directory when unavailable.
    static var applicationSupportDirectory: URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let url = urls.first {
            return url
        }
        // Fallback to documents directory if application support is unavailable (e.g., in previews).
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

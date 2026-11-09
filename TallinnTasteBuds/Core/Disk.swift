import Foundation

/// Where the content files live between launches.
///
/// Three layers, newest first: what the site answered this time, what it
/// answered last time (kept here, in Application Support), and the snapshot
/// compiled into the build under `Seed/`. A first launch on a plane still has a
/// map, and a launch with the site down has yesterday's.
enum Disk {
    private static var folder: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = root.appendingPathComponent("content", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func read(_ name: String) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent(name))
    }

    static func write(_ data: Data, _ name: String) {
        try? data.write(to: folder.appendingPathComponent(name), options: .atomic)
    }

    /// A file compiled into the app. Xcode's synchronised folder copies the
    /// resources flat into the bundle, but this also looks under `Seed/` in
    /// case a future project setting keeps the folder.
    static func bundled(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Seed")
    }

    static func seed(_ name: String) -> Data? {
        guard let url = bundled(name, "json") else { return nil }
        return try? Data(contentsOf: url)
    }
}

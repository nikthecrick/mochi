import Foundation

enum PetStore {
    static var directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Mochi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // migration: pets saved by the previous name (Mochi) carry over
        let old = base.appendingPathComponent("Mochi/pet.json", isDirectory: false)
        let new = dir.appendingPathComponent("pet.json", isDirectory: false)
        if !FileManager.default.fileExists(atPath: new.path),
           FileManager.default.fileExists(atPath: old.path) {
            try? FileManager.default.copyItem(at: old, to: new)
            if FileManager.default.fileExists(atPath: new.path) {
                print("Mochi: migrated your pet from the old Mochi save.")
            }
        }
        return dir
    }()

    private static var fileURL: URL { directory.appendingPathComponent("pet.json") }

    static func save(_ m: PetModel) {
        guard let data = try? JSONEncoder().encode(m) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> PetModel? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PetModel.self, from: data)
    }

    static func reset() { try? FileManager.default.removeItem(at: fileURL) }
}
import Foundation
import AppKit
import UniformTypeIdentifiers

/// Groundwork for the "borrow my pet" feature:
/// a friend can care for your pet when you don't have time.
/// The whole pet travels in a tiny .mochi JSON snapshot.
/// UI hooks are wired but deliberately kept out of the basic menu
/// (only visible under --dev for now).
struct PetSnapshot: Codable {
    static let formatID = "mochi/pet/v1"
    var format = PetSnapshot.formatID
    var exportedAt = Date()
    var owner = ProcessInfo.processInfo.hostName
    var pet: PetModel
    var borrowedFrom: String?
    var borrowedUntil: Date?
}

enum BorrowManager {
    static let fileExtension = "mochi"

    /// LATER: full borrow UX — pick a friend, lend for N hours,
    /// auto-return reminder, shared care credits. The format below is ready.

    static func export(_ model: PetModel, to url: URL) throws {
        let snapshot = PetSnapshot(pet: model)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    /// Import a borrowed pet: stats, name and age carry over;
    /// the previous owner is remembered in `borrowedFrom` (prepared field).
    static func importPet(at url: URL) throws -> PetModel {
        let data = try Data(contentsOf: url)
        let snapshot = try JSONDecoder().decode(PetSnapshot.self, from: data)
        guard snapshot.format == PetSnapshot.formatID else {
            throw NSError(domain: "Mochi", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Not a Mochi pet snapshot (\(snapshot.format))"])
        }
        var pet = snapshot.pet
        pet.borrowedFrom = snapshot.owner
        pet.lastTick = Date()   // resumes from import time
        return pet
    }

    static var contentType: UTType {
        UTType(filenameExtension: fileExtension) ?? .json
    }
}
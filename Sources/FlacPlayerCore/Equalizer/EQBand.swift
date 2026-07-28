import Foundation

public struct EQBand: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var frequency: Double
    public var gainDB: Double
    public var q: Double

    public init(id: UUID = UUID(), frequency: Double, gainDB: Double = 0, q: Double = 1.0) {
        self.id = id
        self.frequency = frequency
        self.gainDB = gainDB
        self.q = q
    }
}

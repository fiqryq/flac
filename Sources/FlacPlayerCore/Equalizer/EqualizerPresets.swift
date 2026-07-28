import Foundation

public enum EqualizerBands {
    public static let frequencies: [Double] = [60, 150, 400, 1000, 2400, 15000]
}

public struct EQPreset: Identifiable, Hashable, Sendable {
    public let name: String
    public let gains: [Double]
    public var id: String { name }

    public init(name: String, gains: [Double]) {
        precondition(gains.count == EqualizerBands.frequencies.count)
        self.name = name
        self.gains = gains
    }

    public static let flat = EQPreset(name: "Flat", gains: [0, 0, 0, 0, 0, 0])
    public static let bassBoost = EQPreset(name: "Bass Boost", gains: [6, 4, 1, 0, -1, 0])
    public static let bassReducer = EQPreset(name: "Bass Reducer", gains: [-6, -4, -1, 0, 0, 0])
    public static let trebleBoost = EQPreset(name: "Treble Boost", gains: [0, -1, 0, 1, 4, 6])
    public static let trebleReducer = EQPreset(name: "Treble Reducer", gains: [0, 0, 0, -1, -4, -6])
    public static let vocalBoost = EQPreset(name: "Vocal Boost", gains: [-2, 0, 3, 4, 3, 0])
    public static let loudness = EQPreset(name: "Loudness", gains: [5, 2, -1, -1, 2, 5])
    public static let rock = EQPreset(name: "Rock", gains: [4, 3, -2, -1, 2, 4])
    public static let pop = EQPreset(name: "Pop", gains: [-1, 2, 4, 3, 0, 1])
    public static let jazz = EQPreset(name: "Jazz", gains: [3, 2, 0, 1, 2, 3])
    public static let classical = EQPreset(name: "Classical", gains: [2, 1, -1, -1, 0, 4])
    public static let dance = EQPreset(name: "Dance", gains: [6, 4, -2, -1, 3, 5])
    public static let acoustic = EQPreset(name: "Acoustic", gains: [3, 2, 1, 2, 3, 2])
    public static let hipHop = EQPreset(name: "Hip-Hop", gains: [7, 5, 1, -1, 1, 3])
    public static let spokenWord = EQPreset(name: "Spoken Word", gains: [-4, -2, 2, 4, 3, -1])

    public static let all: [EQPreset] = [
        .flat,
        .rock, .pop, .jazz, .classical, .dance, .acoustic, .hipHop, .spokenWord,
        .bassBoost, .bassReducer, .trebleBoost, .trebleReducer, .vocalBoost, .loudness,
    ]
}

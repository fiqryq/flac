import Foundation
import SwiftData

@Model
public final class WatchedFolder {
    @Attribute(.unique) public var path: String
    public var dateAdded: Date

    public init(path: String, dateAdded: Date = Date()) {
        self.path = path
        self.dateAdded = dateAdded
    }
}

import Foundation
import SwiftData

@Model
final class FrequentDestination {
    @Attribute(.unique) var name: String
    var address: String

    init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}

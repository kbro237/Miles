import Foundation
import SwiftData

@Model
final class PaidQuarter {
    @Attribute(.unique) var quarterID: String
    var isPaid: Bool

    init(quarterID: String, isPaid: Bool = true) {
        self.quarterID = quarterID
        self.isPaid = isPaid
    }
}

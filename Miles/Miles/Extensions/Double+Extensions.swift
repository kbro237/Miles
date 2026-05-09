import Foundation

extension Double {
    var roundedTo2dp: Double {
        (self * 100).rounded() / 100
    }

    var roundedTo1dp: Double {
        (self * 10).rounded() / 10
    }
}

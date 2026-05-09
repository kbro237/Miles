import Foundation

struct IRSRateService {

    static var currentYearDefaultRate: Int {
        let year = Calendar.current.component(.year, from: Date())
        return defaultRate(for: year)
    }

    static func defaultRate(for year: Int) -> Int {
        switch year {
        case 2026: return 70
        case 2025: return 70
        case 2024: return 67
        case 2023: return 65
        case 2022: return 62
        default: return 70
        }
    }

    static func fetchCurrentRate() async -> Int {
        currentYearDefaultRate
    }
}

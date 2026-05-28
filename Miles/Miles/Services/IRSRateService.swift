import Foundation

struct IRSRateService {

    private static let manualKey = "manualRateCents"

    static var currentDefaultRate: Int {
        let manual = UserDefaults.standard.integer(forKey: manualKey)
        if manual > 0 {
            return manual
        }
        let year = Calendar.current.component(.year, from: Date())
        return defaultRate(for: year)
    }

    static var manualOverride: Int {
        get { UserDefaults.standard.integer(forKey: manualKey) }
        set { UserDefaults.standard.set(newValue, forKey: manualKey) }
    }

    static var isManual: Bool {
        manualOverride > 0
    }

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
        let currentYear = Calendar.current.component(.year, from: Date())

        guard let url = URL(string: "https://www.irs.gov/tax-professionals/standard-mileage-rates") else {
            return currentDefaultRate
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return currentDefaultRate
            }

            if let rate = parseRate(html: html, expectedYear: currentYear) {
                return rate
            }
            if let rate = parseRate(html: html, expectedYear: currentYear - 1) {
                return rate
            }
            return currentDefaultRate
        } catch {
            return currentDefaultRate
        }
    }

    private static func parseRate(html: String, expectedYear: Int) -> Int? {
        let yearPrefix = "standard mileage rates for \(expectedYear)"

        guard let yearRange = html.range(of: yearPrefix, options: .caseInsensitive) else {
            return nil
        }

        let remaining = html[yearRange.upperBound...]
        guard let businessRange = remaining.range(of: "business:", options: .caseInsensitive) else {
            return nil
        }

        let afterBusiness = remaining[businessRange.upperBound...]

        var numberText = ""
        var foundDigit = false
        for char in afterBusiness {
            if char.isNumber {
                numberText.append(char)
                foundDigit = true
            } else if foundDigit {
                break
            } else if char == " " || char == "\u{00a0}" {
                continue
            } else {
                break
            }
        }

        guard let rate = Int(numberText), rate > 0, rate < 200 else { return nil }
        return rate
    }
}

import Foundation

struct IRSRateService {

    private static let manualKey = "manualRateCents"

    static var currentDefaultRate: Double {
        let manual = UserDefaults.standard.double(forKey: manualKey)
        if manual > 0 {
            return manual
        }
        let year = Calendar.current.component(.year, from: Date())
        return defaultRate(for: year)
    }

    static var manualOverride: Double {
        get { UserDefaults.standard.double(forKey: manualKey) }
        set { UserDefaults.standard.set(newValue, forKey: manualKey) }
    }

    static var isManual: Bool {
        manualOverride > 0
    }

    static var currentYearDefaultRate: Double {
        let year = Calendar.current.component(.year, from: Date())
        return defaultRate(for: year)
    }

    static func defaultRate(for year: Int) -> Double {
        switch year {
        case 2026: return 72.5
        case 2025: return 70.0
        case 2024: return 67.0
        case 2023: return 65.5
        case 2022: return 62.0
        default: return 70.0
        }
    }

    static func fetchCurrentRate() async -> Double {
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

    private static func parseRate(html: String, expectedYear: Int) -> Double? {
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
            if char.isNumber || char == "." {
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

        guard let rate = Double(numberText), rate > 0, rate < 200 else { return nil }
        return rate
    }
}

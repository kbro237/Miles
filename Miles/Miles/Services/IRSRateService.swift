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
        guard let url = URL(string: "https://www.irs.gov/tax-professionals/standard-mileage-rates") else {
            return currentYearDefaultRate
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return currentYearDefaultRate
            }
            return parseRateFromHTML(html) ?? currentYearDefaultRate
        } catch {
            return currentYearDefaultRate
        }
    }

    private static func parseRateFromHTML(_ html: String) -> Int? {
        let patterns = [
            "business rate\\s*(?:for \\d{4})?\\s*(?:is|:) \\$?(\\d+)\\.?(\\d{2})?",
            "(\\d+)\\.?(\\d{2})?\\s*¢? per mile for business"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range) {
                    let dollarRange = match.range(at: 1)
                    if let swiftRange = Range(dollarRange, in: html),
                       let dollars = Int(html[swiftRange]) {
                        return dollars
                    }
                }
            }
        }
        return nil
    }
}

import MapKit

enum DistanceCalculatorError: LocalizedError {
    case noResults
    case invalidAddresses

    var errorDescription: String? {
        switch self {
        case .noResults: return "Could not calculate distance between these addresses."
        case .invalidAddresses: return "Please enter valid origin and destination addresses."
        }
    }
}

struct DistanceCalculator {

    static func calculate(origin: String, destination: String) async throws -> Double {
        let request = MKDirections.Request()
        request.transportType = .automobile

        let sourcePlacemark = try await geocode(address: origin)
        let destPlacemark = try await geocode(address: destination)

        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destPlacemark)

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw DistanceCalculatorError.noResults
        }

        return route.distance / 1609.34
    }

    private static func geocode(address: String) async throws -> MKPlacemark {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let location = placemarks.first, let clLocation = location.location else {
            throw DistanceCalculatorError.invalidAddresses
        }
        return MKPlacemark(coordinate: clLocation.coordinate)
    }
}

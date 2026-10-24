import Foundation

/// One entry from /geo/1.0/direct. `local_names` is skipped; we don't need it.
struct GeocodingResultDTO: Decodable, Equatable {
    let name: String
    let lat: Double
    let lon: Double
    let country: String?
    let state: String?
}

import Foundation

/// Lookup between USPS state codes and names. The geocoder only honors the state
/// part of `q` for US locations, and it wants the code, so we normalize to that.
enum USState {
    static let namesByCode: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
        "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
        "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine",
        "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska",
        "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
        "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
        "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island",
        "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas",
        "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
        "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming"
    ]

    private static let codesByLowercasedName: [String: String] = Dictionary(
        uniqueKeysWithValues: namesByCode.map { ($0.value.lowercased(), $0.key) }
    )

    /// "TX", "tx", "Texas" and "texas" all map to "TX". Returns nil for anything else.
    static func code(for input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        if namesByCode[upper] != nil {
            return upper
        }
        return codesByLowercasedName[trimmed.lowercased()]
    }

    static func name(for code: String) -> String? {
        namesByCode[code.uppercased()]
    }
}

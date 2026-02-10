import Foundation

struct City: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let country: Country
    let latitude: Double
    let longitude: Double


}

enum Country: String, Codable, CaseIterable, Identifiable {
    case kosovo = "XK"
    case switzerland = "CH"
    case germany = "DE"
    case austria = "AT"
    case france = "FR"
    case netherlands = "NL"
    case belgium = "BE"
    case sweden = "SE"
    case norway = "NO"
    case denmark = "DK"
    case unitedKingdom = "GB"
    case italy = "IT"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .kosovo: return "Kosova"
        case .switzerland: return "Zvicra"
        case .germany: return "Gjermania"
        case .austria: return "Austria"
        case .france: return "Franca"
        case .netherlands: return "Holanda"
        case .belgium: return "Belgjika"
        case .sweden: return "Suedia"
        case .norway: return "Norvegjia"
        case .denmark: return "Danimarka"
        case .unitedKingdom: return "Britania"
        case .italy: return "Italia"
        }
    }

    var flag: String {
        switch self {
        case .kosovo: return "🇽🇰"
        case .switzerland: return "🇨🇭"
        case .germany: return "🇩🇪"
        case .austria: return "🇦🇹"
        case .france: return "🇫🇷"
        case .netherlands: return "🇳🇱"
        case .belgium: return "🇧🇪"
        case .sweden: return "🇸🇪"
        case .norway: return "🇳🇴"
        case .denmark: return "🇩🇰"
        case .unitedKingdom: return "🇬🇧"
        case .italy: return "🇮🇹"
        }
    }
}

extension City {
    // MARK: - Kosovo Cities (Official BIM data for 2026)
    static let kosovoCities: [City] = [
        City(id: "prishtina", name: "Prishtina", country: .kosovo, latitude: 42.6629, longitude: 21.1655),
        City(id: "prizren", name: "Prizren", country: .kosovo, latitude: 42.2139, longitude: 20.7397),
        City(id: "peja", name: "Peja", country: .kosovo, latitude: 42.6592, longitude: 20.2883),
        City(id: "gjakova", name: "Gjakova", country: .kosovo, latitude: 42.3803, longitude: 20.4308),
        City(id: "mitrovica", name: "Mitrovica", country: .kosovo, latitude: 42.8914, longitude: 20.8660),
        City(id: "ferizaj", name: "Ferizaj", country: .kosovo, latitude: 42.3702, longitude: 21.1553),
        City(id: "gjilan", name: "Gjilan", country: .kosovo, latitude: 42.4635, longitude: 21.4694)
    ]

    // MARK: - Switzerland Cities
    static let switzerlandCities: [City] = [
        City(id: "zurich", name: "Zürich", country: .switzerland, latitude: 47.3769, longitude: 8.5417),
        City(id: "geneva", name: "Genève", country: .switzerland, latitude: 46.2044, longitude: 6.1432),
        City(id: "basel", name: "Basel", country: .switzerland, latitude: 47.5596, longitude: 7.5886),
        City(id: "bern", name: "Bern", country: .switzerland, latitude: 46.9480, longitude: 7.4474),
        City(id: "lausanne", name: "Lausanne", country: .switzerland, latitude: 46.5197, longitude: 6.6323),
        City(id: "winterthur", name: "Winterthur", country: .switzerland, latitude: 47.5001, longitude: 8.7240),
        City(id: "stgallen", name: "St. Gallen", country: .switzerland, latitude: 47.4245, longitude: 9.3767),
        City(id: "lugano", name: "Lugano", country: .switzerland, latitude: 46.0037, longitude: 8.9511)
    ]

    // MARK: - Germany Cities
    static let germanyCities: [City] = [
        City(id: "berlin", name: "Berlin", country: .germany, latitude: 52.5200, longitude: 13.4050),
        City(id: "munich", name: "München", country: .germany, latitude: 48.1351, longitude: 11.5820),
        City(id: "frankfurt", name: "Frankfurt", country: .germany, latitude: 50.1109, longitude: 8.6821),
        City(id: "hamburg", name: "Hamburg", country: .germany, latitude: 53.5511, longitude: 9.9937),
        City(id: "cologne", name: "Köln", country: .germany, latitude: 50.9375, longitude: 6.9603),
        City(id: "dusseldorf", name: "Düsseldorf", country: .germany, latitude: 51.2277, longitude: 6.7735),
        City(id: "stuttgart", name: "Stuttgart", country: .germany, latitude: 48.7758, longitude: 9.1829),
        City(id: "dortmund", name: "Dortmund", country: .germany, latitude: 51.5136, longitude: 7.4653)
    ]

    // MARK: - Austria Cities
    static let austriaCities: [City] = [
        City(id: "vienna", name: "Wien", country: .austria, latitude: 48.2082, longitude: 16.3738),
        City(id: "graz", name: "Graz", country: .austria, latitude: 47.0707, longitude: 15.4395),
        City(id: "linz", name: "Linz", country: .austria, latitude: 48.3069, longitude: 14.2858),
        City(id: "salzburg", name: "Salzburg", country: .austria, latitude: 47.8095, longitude: 13.0550),
        City(id: "innsbruck", name: "Innsbruck", country: .austria, latitude: 47.2692, longitude: 11.4041)
    ]

    // MARK: - France Cities
    static let franceCities: [City] = [
        City(id: "paris", name: "Paris", country: .france, latitude: 48.8566, longitude: 2.3522),
        City(id: "marseille", name: "Marseille", country: .france, latitude: 43.2965, longitude: 5.3698),
        City(id: "lyon", name: "Lyon", country: .france, latitude: 45.7640, longitude: 4.8357),
        City(id: "strasbourg", name: "Strasbourg", country: .france, latitude: 48.5734, longitude: 7.7521),
        City(id: "toulouse", name: "Toulouse", country: .france, latitude: 43.6047, longitude: 1.4442)
    ]

    // MARK: - Netherlands Cities
    static let netherlandsCities: [City] = [
        City(id: "amsterdam", name: "Amsterdam", country: .netherlands, latitude: 52.3676, longitude: 4.9041),
        City(id: "rotterdam", name: "Rotterdam", country: .netherlands, latitude: 51.9244, longitude: 4.4777),
        City(id: "hague", name: "Den Haag", country: .netherlands, latitude: 52.0705, longitude: 4.3007),
        City(id: "utrecht", name: "Utrecht", country: .netherlands, latitude: 52.0907, longitude: 5.1214)
    ]

    // MARK: - Belgium Cities
    static let belgiumCities: [City] = [
        City(id: "brussels", name: "Bruxelles", country: .belgium, latitude: 50.8503, longitude: 4.3517),
        City(id: "antwerp", name: "Antwerpen", country: .belgium, latitude: 51.2194, longitude: 4.4025),
        City(id: "ghent", name: "Gent", country: .belgium, latitude: 51.0543, longitude: 3.7174),
        City(id: "liege", name: "Liège", country: .belgium, latitude: 50.6292, longitude: 5.5797)
    ]

    // MARK: - Scandinavian Cities
    static let swedenCities: [City] = [
        City(id: "stockholm", name: "Stockholm", country: .sweden, latitude: 59.3293, longitude: 18.0686),
        City(id: "gothenburg", name: "Göteborg", country: .sweden, latitude: 57.7089, longitude: 11.9746),
        City(id: "malmo", name: "Malmö", country: .sweden, latitude: 55.6050, longitude: 13.0038)
    ]

    static let norwayCities: [City] = [
        City(id: "oslo", name: "Oslo", country: .norway, latitude: 59.9139, longitude: 10.7522),
        City(id: "bergen", name: "Bergen", country: .norway, latitude: 60.3913, longitude: 5.3221)
    ]

    static let denmarkCities: [City] = [
        City(id: "copenhagen", name: "København", country: .denmark, latitude: 55.6761, longitude: 12.5683),
        City(id: "aarhus", name: "Aarhus", country: .denmark, latitude: 56.1629, longitude: 10.2039)
    ]

    // MARK: - UK Cities
    static let ukCities: [City] = [
        City(id: "london", name: "London", country: .unitedKingdom, latitude: 51.5074, longitude: -0.1278),
        City(id: "birmingham", name: "Birmingham", country: .unitedKingdom, latitude: 52.4862, longitude: -1.8904),
        City(id: "manchester", name: "Manchester", country: .unitedKingdom, latitude: 53.4808, longitude: -2.2426),
        City(id: "leeds", name: "Leeds", country: .unitedKingdom, latitude: 53.8008, longitude: -1.5491)
    ]

    // MARK: - Italy Cities
    static let italyCities: [City] = [
        City(id: "rome", name: "Roma", country: .italy, latitude: 41.9028, longitude: 12.4964),
        City(id: "milan", name: "Milano", country: .italy, latitude: 45.4642, longitude: 9.1900),
        City(id: "turin", name: "Torino", country: .italy, latitude: 45.0703, longitude: 7.6869),
        City(id: "florence", name: "Firenze", country: .italy, latitude: 43.7696, longitude: 11.2558)
    ]

    // MARK: - All Cities
    static let allCities: [City] = {
        var cities: [City] = []
        cities.append(contentsOf: kosovoCities)
        cities.append(contentsOf: switzerlandCities)
        cities.append(contentsOf: germanyCities)
        cities.append(contentsOf: austriaCities)
        cities.append(contentsOf: franceCities)
        cities.append(contentsOf: netherlandsCities)
        cities.append(contentsOf: belgiumCities)
        cities.append(contentsOf: swedenCities)
        cities.append(contentsOf: norwayCities)
        cities.append(contentsOf: denmarkCities)
        cities.append(contentsOf: ukCities)
        cities.append(contentsOf: italyCities)
        return cities
    }()

    // Cities grouped by country for UI
    static let citiesByCountry: [(country: Country, cities: [City])] = [
        (.kosovo, kosovoCities),
        (.switzerland, switzerlandCities),
        (.germany, germanyCities),
        (.austria, austriaCities),
        (.france, franceCities),
        (.netherlands, netherlandsCities),
        (.belgium, belgiumCities),
        (.sweden, swedenCities),
        (.norway, norwayCities),
        (.denmark, denmarkCities),
        (.unitedKingdom, ukCities),
        (.italy, italyCities)
    ]

    static let `default` = kosovoCities[0] // Prishtina

    static func find(by id: String) -> City? {
        allCities.first { $0.id == id }
    }

    // Check if this city has official embedded prayer times
    var hasOfficialData: Bool {
        country == .kosovo
    }
}

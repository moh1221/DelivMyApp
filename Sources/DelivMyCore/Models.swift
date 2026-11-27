import Foundation

public struct AuthSession: Decodable, Sendable {
    public let token: String
    public let userID: String

    private enum CodingKeys: String, CodingKey { case token = "id", userID = "user_id" }

    public init(token: String, userID: String) {
        self.token = token
        self.userID = userID
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        token = try values.decode(String.self, forKey: .token)
        guard !token.isEmpty, token.utf8.allSatisfy({ (33...126).contains($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: .token, in: values, debugDescription: "Invalid login token.")
        }
        if let text = try? values.decode(String.self, forKey: .userID) {
            userID = text
        } else {
            userID = String(try values.decode(Int.self, forKey: .userID))
        }
    }
}

public enum DeliveryStatus: Int, Sendable {
    case open = 1, inProgress = 2, completed = 3, closed = 4, rejected = 5, unknown = 0

    public var title: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .closed: "Closed"
        case .rejected: "Rejected"
        case .unknown: "Unknown"
        }
    }
}

public struct Profile: Decodable, Sendable {
    public let firstName: String?
    public let lastName: String?
    public let picture: String?

    private enum CodingKeys: String, CodingKey {
        case firstName = "first_name", lastName = "last_name", picture
    }

    public var displayName: String? {
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

public struct Delivery: Decodable, Sendable {
    public let profile: Profile?
    public let receiptImage: String?
    public let completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case profile, receiptImage = "receipt_img", completedAt = "completed_at"
    }
}

public struct Coordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init?(latitude: Double, longitude: Double) {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    var queryValue: String { "\(latitude),\(longitude)" }
}

public struct DeliveryLocation: Decodable, Sendable {
    public let address: String?
    public let coordinate: Coordinate?

    private enum CodingKeys: String, CodingKey { case address, latitude = "Lat", longitude = "Long" }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        address = try values.decodeIfPresent(String.self, forKey: .address)
        if let latitude = try values.flexibleDouble(.latitude), let longitude = try values.flexibleDouble(.longitude) {
            coordinate = Coordinate(latitude: latitude, longitude: longitude)
        } else {
            coordinate = nil
        }
    }
}

public struct DeliveryItem: Decodable, Identifiable, Sendable {
    public let id: Int
    public let name: String?
    public let notes: String?

    private enum CodingKeys: String, CodingKey { case id, name = "ItemsName", notes = "ItemDescription" }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.requiredInt(.id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
    }
}

public struct DeliveryRequest: Decodable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let status: DeliveryStatus
    public let category: String?
    public let cost: Decimal?
    public let fee: Decimal?
    public let due: Date?
    public let profile: Profile?
    public let delivery: Delivery?
    public let location: DeliveryLocation?
    public let items: [DeliveryItem]?

    private struct Category: Decodable {
        let name: String?
        private enum CodingKeys: String, CodingKey { case name = "CatName" }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name = "PlaceName", statusID = "status_id", category, cost, fee = "fees"
        case due = "delivery_at", profile, delivery = "deliver", location, items
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.requiredInt(.id)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Request #\(id)"
        status = DeliveryStatus(rawValue: (try? values.requiredInt(.statusID)) ?? 0) ?? .unknown
        category = try values.decodeIfPresent(Category.self, forKey: .category)?.name
        cost = try values.flexibleDecimal(.cost)
        fee = try values.flexibleDecimal(.fee)
        due = try values.decodeIfPresent(Date.self, forKey: .due)
        profile = try values.decodeIfPresent(Profile.self, forKey: .profile)
        delivery = try values.decodeIfPresent(Delivery.self, forKey: .delivery)
        location = try values.decodeIfPresent(DeliveryLocation.self, forKey: .location)
        items = try values.decodeIfPresent([DeliveryItem].self, forKey: .items)
    }

    public var isAcceptable: Bool { status == .open && (due.map { $0 > Date() } ?? false) }
}

public struct SearchBounds: Sendable {
    public let southwest: Coordinate
    public let northeast: Coordinate
    public let center: Coordinate

    public init?(southwest: Coordinate, northeast: Coordinate, center: Coordinate) {
        guard southwest.latitude <= northeast.latitude, southwest.longitude <= northeast.longitude else {
            return nil
        }
        self.southwest = southwest
        self.northeast = northeast
        self.center = center
    }
}

private extension KeyedDecodingContainer {
    func requiredInt(_ key: Key) throws -> Int {
        if let number = try? decode(Int.self, forKey: key) { return number }
        if let text = try? decode(String.self, forKey: key), let number = Int(text) { return number }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected an integer.")
    }

    func flexibleDouble(_ key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let number = try? decode(Double.self, forKey: key) { return number }
        if let text = try? decode(String.self, forKey: key), let number = Double(text) { return number }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected a number.")
    }

    func flexibleDecimal(_ key: Key) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let number = try? decode(Decimal.self, forKey: key) { return number }
        if let text = try? decode(String.self, forKey: key),
           text.wholeMatch(of: /-?[0-9]+(?:\.[0-9]+)?(?:[eE][+\-]?[0-9]+)?/) != nil,
           let number = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) {
            return number
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected a decimal.")
    }
}

import Foundation

struct Airport: Codable, Hashable {
    let name: String
    let country: String
    let timeZone: String
    let latitude: Double
    let longitude: Double
    let code: String
}

struct City: Codable {
    let name: String
    let destinations: [Destination]
}

struct Destination: Codable {
    let name: String
    let price: Double
}



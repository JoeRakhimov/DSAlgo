import Foundation

struct City: Codable {
    let name: String
    let destinations: [Destination]
}

struct Destination: Codable {
    let name: String
    let price: Double
}

import SwiftUI
import Combine

struct ContentView: View {
    
    @State private var codes: String = "NAP,BUD,LIS,BER"
    @State private var graph: [City] = []
    @State private var message: String = ""
    @State private var cancellable: AnyCancellable?
    
    var body: some View {
        VStack {
            
            TextField("Enter IATA codes for airports separated with comma", text: $codes)
                .frame(maxWidth: .infinity)
                .padding()
                .border(Color.gray, width: 1)
            
            Button(action: {
                self.fetchDestinations(codes: codes)
//                let response: [City] = [
//                    City(name: "NAP", destinations: [
//                        Destination(name: "BUD", price: 26.95),
//                        Destination(name: "LIS", price: 45.17)
//                    ]),
//                    City(name: "BUD", destinations: [
//                        Destination(name: "NAP", price: 18.07),
//                        Destination(name: "LIS", price: 55.76)
//                    ]),
//                    City(name: "LIS", destinations: [
//                        Destination(name: "NAP", price: 53.35),
//                        Destination(name: "BUD", price: 66.98)
//                    ])
//                ]
//                tsp(graph: response)
            }) {
                Text("Find optimal path")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            Text(message)
                .foregroundColor(.gray)
            
            Spacer()
        }.padding(24)
    }
    
    private func fetchDestinations(codes: String) {
        guard let url = URL(string: "https://api.cheapta.com/test/graph/destinations?nodes="+codes) else {
            print("Invalid URL")
            return
        }
        self.cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [City].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error: \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { response in
                tsp(graph: response)
            })
    }
    
    func tsp(graph: [City]){
        
        let startingCity = "NAP"
        
//        let (shortestPathBruteForce, shortestDistanceBruteForce) = findShortestPathBruteForce(startingCity: startingCity, allCities: graph)
//        print("\nShortest path (brute force): \(shortestPathBruteForce) with distance \(shortestDistanceBruteForce)")
        
        var distances = [[Double]](repeating: [Double](repeating: Double.infinity, count: graph.count), count: graph.count)
        for (i, city) in graph.enumerated() {
            for destination in city.destinations {
                if let index = graph.firstIndex(where: { $0.name == destination.name }) {
                    distances[i][index] = destination.price
                }
            }
        }
        // Call the function to solve TSP and print the result
        let result = solveTSP(distances: distances)
        var message_to_show = ""
        for index in result.path {
            message_to_show = message_to_show + " " + graph[index].name
        }
        message = message_to_show+": "+String(result.length)
        print("Shortest path (dynamic programming): \(result.path) with distance \(result.length)")
        
        
    }
    
    // Function to calculate the total price of a path
    func calculatePathPrice(path: [String], cities: [String: City]) -> Double {
        var totalPrice = 0.0
        for i in 0..<path.count - 1 {
            let currentCity = cities[path[i]]!
            let nextCity = cities[path[i + 1]]!
            for destination in currentCity.destinations {
                if destination.name == nextCity.name {
                    totalPrice += destination.price
                    break
                }
            }
        }
        return totalPrice
    }
    
    // Brute force solution
    func tspBruteForce(startingCity: String, currentCity: String, citiesLeft: Set<String>, currentPath: [String], currentDistance: Double, shortestPath: inout [String], shortestDistance: inout Double, allCities: [City]) {
        if citiesLeft.isEmpty {
            let distanceToStartingCity = allCities.first { $0.name == currentCity }!.destinations.first { $0.name == startingCity }!.price
            let totalDistance = currentDistance + distanceToStartingCity
            if totalDistance < shortestDistance {
                shortestDistance = totalDistance
                shortestPath = currentPath + [startingCity]
            }
        } else {
            for city in citiesLeft {
                let remainingCities = citiesLeft.subtracting([city])
                let distanceToNextCity = allCities.first { $0.name == currentCity }!.destinations.first { $0.name == city }!.price
                tspBruteForce(startingCity: startingCity, currentCity: city, citiesLeft: remainingCities, currentPath: currentPath + [city], currentDistance: currentDistance + distanceToNextCity, shortestPath: &shortestPath, shortestDistance: &shortestDistance, allCities: allCities)
            }
        }
    }
    
    func findShortestPathBruteForce(startingCity: String, allCities: [City]) -> ([String], Double) {
        var shortestPath = [String]()
        var shortestDistance = Double.infinity
        let citiesLeft = Set(allCities.map { $0.name }.filter { $0 != startingCity })
        
        tspBruteForce(startingCity: startingCity, currentCity: startingCity, citiesLeft: citiesLeft, currentPath: [], currentDistance: 0, shortestPath: &shortestPath, shortestDistance: &shortestDistance, allCities: allCities)
        
        return (shortestPath, shortestDistance)
    }
    
    func solveTSP(distances: [[Double]]) -> (length: Double, path: [Int]) {
        let numCities = distances.count
        
        // Define the bitmask to represent the set of visited cities
        typealias VisitedSet = UInt16
        
        // Function to check if a city is visited or not
        func isVisited(city: Int, visitedSet: VisitedSet) -> Bool {
            return (visitedSet & (1 << city)) != 0
        }
        
        // Function to mark a city as visited
        func markVisited(city: Int, visitedSet: VisitedSet) -> VisitedSet {
            return visitedSet | (1 << city)
        }
        
        // Initialize memoization table
        var memo = [[Double?]](repeating: [Double?](repeating: nil, count: 1 << numCities), count: numCities)
        
        // Function to solve TSP using Dynamic Programming
        func solveTSP(currentCity: Int, visitedSet: VisitedSet) -> (length: Double, path: [Int]) {
            // If all cities have been visited, return the distance to return to the starting city
            if visitedSet == ((1 << numCities) - 1) {
                return (distances[currentCity][0], [currentCity, 0])
            }
            
            // If the result for the current city and visited set is already memoized, return it
            if let result = memo[currentCity][Int(visitedSet)] {
                return (result, [])
            }
            
            // Initialize the minimum distance to infinity
            var minDistance = Double.infinity
            var minPath: [Int] = []
            
            // Iterate through all cities
            for nextCity in 0..<numCities {
                // If the next city has not been visited yet
                if !isVisited(city: nextCity, visitedSet: visitedSet) {
                    // Calculate the distance from the current city to the next city
                    let distanceToNextCity = distances[currentCity][nextCity]
                    
                    // Mark the next city as visited
                    let updatedVisitedSet = markVisited(city: nextCity, visitedSet: visitedSet)
                    
                    // Recursive call to solve TSP starting from the next city
                    let (distance, path) = solveTSP(currentCity: nextCity, visitedSet: updatedVisitedSet)
                    
                    // Update the minimum distance and path
                    if distanceToNextCity + distance < minDistance {
                        minDistance = distanceToNextCity + distance
                        minPath = [currentCity] + path
                    }
                }
            }
            
            // Memoize the result
            memo[currentCity][Int(visitedSet)] = minDistance
            
            return (minDistance, minPath)
        }
        
        // Start solving TSP from the starting city (city 0)
        let (shortestPathLength, shortestPath) = solveTSP(currentCity: 0, visitedSet: 1)
        return (shortestPathLength, shortestPath)
    }
    
}

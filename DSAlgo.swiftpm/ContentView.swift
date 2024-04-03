import SwiftUI
import Combine
import MapKit

struct ContentView: View {
    
    @State private var airports = [Airport]()
    @State private var line = [CLLocationCoordinate2D]()
    @State private var airportsDict = [String: Airport]()
    @State private var selectedAirportCodes = Array<String>()
    @State private var selectedAirportNames: String = ""
    @State private var prices = [String: Double]()
    @State private var inProgress = false
    @State private var message: String = ""
    @State private var cancellable: AnyCancellable?
    
    var body: some View {
        VStack {
            MapView(annotations: airports.map { airport in
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(airport.latitude) ?? 0.0,
                                                               longitude: CLLocationDegrees(airport.longitude) ?? 0.0)
                annotation.title = airport.name
                annotation.subtitle = airport.code
                return annotation
            }) { annotation in
                let code = annotation.subtitle
                if let index = selectedAirportCodes.firstIndex(of: code!) {
                    selectedAirportCodes.remove(at: index)
                } else {
                    selectedAirportCodes.append(code!)
                }
                print(selectedAirportCodes)
                var names = [String]()
                for code in selectedAirportCodes {
                    if let airport = airportsDict[code] {
                        names.append(airport.name)
                    }
                }
                selectedAirportNames = names.joined(separator: ", ")
                print(selectedAirportNames)
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                fetchAirports()
            }
            
            TextField("Enter IATA codes for airports separated with comma", text: $selectedAirportNames)
                .frame(maxWidth: .infinity)
                .padding()
                .border(Color.gray, width: 1)
            
            Button(action: {
                if(selectedAirportCodes.count >= 2){
                    inProgress = true
                    self.fetchDestinations(codes: selectedAirportCodes.joined(separator: ","))
                }
            }) {
                Text("Find optimal path")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            if inProgress {
                ProgressView("Please wait ...")
            } else {
                Text(message)
                    .foregroundColor(.gray)
            }
            
        }.padding(24)
    }
    
    private func fetchAirports() {
        guard let url = URL(string: "https://api.cheapta.com/test/graph/airports") else {
            print("Invalid URL")
            return
        }
        inProgress = true
        self.cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [Airport].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error: \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { response in
                airports = response
                for airport in airports {
                    airportsDict[airport.code]=airport
                }
                inProgress = false
            })
    }
    
    private func fetchDestinations(codes: String) {
        print("fetchDestinations: "+codes)
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
                for origin in response {
                    for destination in origin.destinations {
                        prices[origin.name+destination.name]=destination.price
                    }
                }
                findOptimalPath(graph: response)
            })
    }
    
    func findOptimalPath(graph: [City]){
        
//        let distances = [[0.0, 10.0, 15.0, 20.0], [5.0, 0.0, 9.0, 10.0], [6.0, 13.0, 0.0, 12.0], [8.0, 8.0, 9.0, 0]]
        var distances = [[Double]](repeating: [Double](repeating: Double.infinity, count: graph.count), count: graph.count)
        for (i, city) in graph.enumerated() {
            distances[i][i] = 0.0
            for destination in city.destinations {
                if let index = graph.firstIndex(where: { $0.name == destination.name }) {
                    distances[i][index] = destination.price
                }
            }
        }
        
        // Call the function to solve TSP and print the result
        print(distances)
        let result = solveTSP(distances: distances)
        
        if result.length == Double.infinity {
            message = "Could not find optimal path"
        } else {
            var message_to_show = ""
            var previousAirportCode = String?(nil)
            print(result.path)
            for index in result.path {
                let code = graph[index].name
                print(code)
                if previousAirportCode != nil {
                    if let previousAirport = airportsDict[previousAirportCode!] {
                        if let currentAirport = airportsDict[code] {
                            message_to_show = message_to_show + "\n" + previousAirport.name + "-" + currentAirport.name + ": $"+String(prices[previousAirport.code+currentAirport.code]!)
                        }
                    }
                }
                previousAirportCode = code
            }
            message = message_to_show+"\nTotal: $"+String(format: "%.2f", result.length)
            print("Shortest path (dynamic programming): \(result.path) with distance \(result.length)")
        }
        
        
        inProgress = false
        
    }
    
    func solveTSP(distances: [[Double]]) -> (length: Double, path: [Int]) {
        
        let numCities = distances.count
        
        // Initialize memoization table
        var memo = [Int: [Set<Int>: Double]]()
        
        // Function to solve TSP using Dynamic Programming
        func solveTSP(currentCity: Int, visitedCities: Set<Int>) -> (length: Double, path: [Int]) {
            // If all cities have been visited, return the distance to return to the starting city
            if visitedCities.count == numCities {
                return (distances[currentCity][0], [currentCity, 0])
            }
            
            // If the result for the current city and visited set is already memoized, return it
            if let result = memo[currentCity]?[visitedCities] {
                return (result, [])
            }
            
            // Initialize the minimum distance to infinity
            var minDistance = Double.infinity
            var minPath: [Int] = []
            
            // Iterate through all cities
            for nextCity in 0..<numCities {
                // If the next city has not been visited yet
                if !visitedCities.contains(nextCity) {
                    // Calculate the distance from the current city to the next city
                    let distanceToNextCity = distances[currentCity][nextCity]
                    
                    // Update the visited set by adding the next city
                    let updatedVisitedCities = visitedCities.union([nextCity])
                    
                    // Recursive call to solve TSP starting from the next city
                    let (distance, path) = solveTSP(currentCity: nextCity, visitedCities: updatedVisitedCities)
                    
                    // Update the minimum distance and path
                    if distanceToNextCity + distance < minDistance {
                        minDistance = distanceToNextCity + distance
                        minPath = [currentCity] + path
                    }
                }
            }
            
            // Memoize the result
            if memo[currentCity] == nil {
                memo[currentCity] = [:]
            }
            memo[currentCity]?[visitedCities] = minDistance
            
            return (minDistance, minPath)
        }
        
        // Start solving TSP from the starting city (city 0)
        let (shortestPathLength, shortestPath) = solveTSP(currentCity: 0, visitedCities: [0])
        return (shortestPathLength, shortestPath)
    }
    
}

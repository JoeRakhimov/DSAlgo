import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    var annotations: [MKPointAnnotation]
    var markerClickHandler: ((MKPointAnnotation) -> Void)? // Define a closure for handling marker clicks
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator // Set the delegate
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)
        uiView.addAnnotations(annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? MKPointAnnotation else {
                return
            }
            parent.markerClickHandler?(annotation) // Call the marker click handler
        }
    }
}

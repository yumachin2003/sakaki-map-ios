//
//  LocationManager.swift
//  shinshu-fesnav
//
//  Created by Yuma on 2026/10/12.
//

import Foundation
import Combine
import MapKit
                       
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  let manager = CLLocationManager()
  @Published var region = MKCoordinateRegion()
  
  override init() {
    super.init()
    manager.delegate = self
    manager.requestWhenInUseAuthorization()
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 2
    manager.startUpdatingLocation()
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    locations.last.map {
      let center = CLLocationCoordinate2D(
        latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude
      )
      
      region = MKCoordinateRegion(
        center: center,
        latitudinalMeters: 100.0,
        longitudinalMeters: 100.0
      )
    }
  }
}

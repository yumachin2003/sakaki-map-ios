//
//  Memory.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/19.
//

import Foundation
import MapKit

/// APIから取得する思い出データ（必要な項目のみ）
struct Memory: Decodable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

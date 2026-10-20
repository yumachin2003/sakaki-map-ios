//
//  MemoryMapView.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/19.
//

import SwiftUI
import MapKit

extension CLLocationCoordinate2D {
    static let nagano_univ = CLLocationCoordinate2D(
        latitude: 36.36915007647547,
        longitude: 138.22364515597747
    )
}

/// 思い出のピンを表示する地図ビュー
struct MemoryMapView: View {
    @State private var memories: [Memory] = []

    var body: some View {
        Map(
            initialPosition: .camera(
                MapCamera(centerCoordinate: .nagano_univ, distance: 500000)
            )
        ) {
            Marker(
                "Nagano University",
                systemImage: "graduationcap.fill",
                coordinate: .nagano_univ
            )
            // APIから取得した思い出の座標にピンを立てる
            ForEach(memories) { memory in
                Marker(memory.name, coordinate: memory.coordinate)
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
        }
        .task {
            do {
                memories = try await MemoryService.fetchMemories()
            } catch {
                print("データの取得に失敗しました: \(error)")
            }
        }
    }
}

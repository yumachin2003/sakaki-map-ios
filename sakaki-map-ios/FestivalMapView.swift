//
//  FestivalMapView.swift
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

/// 祭りのピンを表示する地図ビュー
struct FestivalMapView: View {
    @State private var festivals: [Festival] = []

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
            // APIから取得した祭りの座標にピンを立てる
            ForEach(festivals) { festival in
                Marker(festival.name, coordinate: festival.coordinate)
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
        }
        .task {
            do {
                festivals = try await FestivalService.fetchFestivals()
            } catch {
                print("データの取得に失敗しました: \(error)")
            }
        }
    }
}

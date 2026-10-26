//
//  ContentView.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/08.
//

import SwiftUI
import MapKit

extension CLLocationCoordinate2D {
    static let nagano_univ = CLLocationCoordinate2D(
        latitude: 36.36915007647547,
        longitude: 138.22364515597747
    )
}

/// === 地図ビューの定義 ===
struct MemoryMapView: View {
    @State private var memories: [Memory] = []
    @Namespace private var mapScope

    var body: some View {
        Map(
            initialPosition: .camera(
                MapCamera(centerCoordinate: .nagano_univ, distance: 60000)
            ),
            scope: mapScope
        ) {
            ForEach(memories) { memory in
                Marker(memory.name, coordinate: memory.coordinate)
            }
            UserAnnotation()
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                MapUserLocationButton(scope: mapScope)
                    .buttonBorderShape(.circle)
                    .glassEffect(.regular.interactive(), in: Circle())
                MapCompass(scope: mapScope)
                    .buttonBorderShape(.circle)
                    .mapControlVisibility(.visible)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .padding(.trailing, 16)
            .padding(.bottom, 32)
        }
        .mapControls {}
        .mapScope(mapScope)
        .task {
            do {
                memories = try await MemoryService.fetchMemories()
                print("サーバーデータ取得完了")
            } catch {
                print("データの取得に失敗しました: \(error)")
            }
        }
    }
}

/// === アプリのメイン画面 ===
struct ContentView: View {
    var body: some View {
        MemoryMapView() // 地図ビュー
    }
}


#Preview {
    ContentView()
}

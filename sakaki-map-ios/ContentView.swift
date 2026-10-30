//
//  ContentView.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/08.
//

import SwiftUI

/// === アプリのメイン画面 ===
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        MemoryMapView()
    }
}

#Preview {
    ContentView()
}

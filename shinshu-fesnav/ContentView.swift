//
//  ContentView.swift
//  shinshu-fesnav
//
//  Created by Yuma on 2026/10/08.
//

import SwiftUI
import SwiftData
import MapKit

extension CLLocationCoordinate2D {
    static let nagano_univ = CLLocationCoordinate2D(
        latitude: 36.36915007647547,
        longitude: 138.22364515597747
    )
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationSplitView {
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
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

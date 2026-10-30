//
//  MemoryMapView.swift
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
    @State private var searchText = ""
    @State private var isListPresented = true
    /// 計測した検索バー（ピル）の高さ
    @State private var searchBarHeight: CGFloat = 46
    /// 計測した現在のシート高さ
    @State private var sheetHeight: CGFloat = 0
    /// 画面に実際に描画されているシート上端のY座標（グローバル座標）
    @State private var sheetTopY: CGFloat?
    /// ボタンを置く領域の下端のY座標（グローバル座標）
    @State private var controlsAreaMaxY: CGFloat = 0
    @Namespace private var mapScope

    /// 中くらいのディテントの高さ
    private static let midHeight: CGFloat = 320

    /// 検索バーだけがシート中央に収まる最小ディテントの高さ。
    /// 検索バーの実測高さ＋上下マージンで求めるので、リスト領域が0になり上下マージンが均一になる。
    private var collapsedHeight: CGFloat {
        searchBarHeight + MemoryListSheet.searchBarMargin * 2
    }

    /// 中ディテント未満ならマップコントロールを表示（320以上でフェードアウト）
    private var areControlsVisible: Bool {
        sheetHeight < Self.midHeight + 1
    }

    /// シート上端からボタンまでの距離を保つための下側の余白
    private var controlsBottomPadding: CGFloat {
        guard let sheetTopY else { return collapsedHeight + 16 }
        return max(controlsAreaMaxY - sheetTopY, 0) + 16
    }

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
            ZStack(alignment: .bottomTrailing) {
                // ボタンを置ける領域の下端を計測する（余白の基準）
                Color.clear
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).maxY
                    } action: { newMaxY in
                        controlsAreaMaxY = newMaxY
                    }

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
                // シート上端に毎フレーム追従させ、ボタンがシートに隠れないようにする
                .padding(.bottom, controlsBottomPadding)
                // 中ディテント（320）以上に開いたらフェードアウトして非表示
                .opacity(areControlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: areControlsVisible)
            }
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
        // 下から出てくる一覧シート（検索バー付き）
        .sheet(isPresented: $isListPresented) {
            MemoryListSheet(memories: memories, searchText: $searchText, searchBarHeight: $searchBarHeight, sheetHeight: $sheetHeight)
                // 画面上のシート上端の位置をフレームごとに求め、ボタン側へ伝える
                .background {
                    SheetTopReader { newTopY in
                        // シートの動きはフレームごとに計算済みなので、こちらでアニメーションは付けない
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            sheetTopY = newTopY
                        }
                    }
                    .ignoresSafeArea()
                }
                .presentationDetents([.height(collapsedHeight), .height(Self.midHeight), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(Self.midHeight)))
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }
}

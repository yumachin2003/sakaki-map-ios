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
    /// フォーカスボタンの表示状態。押すたびに現在地とピン→ピン全体→現在地と循環する。
    private enum FocusMode: CaseIterable {
        case locationAndPins  // 現在地とピン
        case pinsOnly         // ピン全体
        case locationOnly     // 現在地

        /// 循環順で次の状態
        var next: FocusMode {
            let all = FocusMode.allCases
            let index = all.firstIndex(of: self)!
            return all[(index + 1) % all.count]
        }

        /// この状態でフォーカスするためのアイコン
        var iconName: String {
            switch self {
            case .locationAndPins: "plus.viewfinder"
            case .pinsOnly: "mappin.and.ellipse"
            case .locationOnly: "location.fill"
            }
        }

        /// 長押しメニューに表示する名前
        var title: String {
            switch self {
            case .locationAndPins: "現在地とピン"
            case .pinsOnly: "ピン全体"
            case .locationOnly: "現在地"
            }
        }
    }

    @StateObject private var locationManager = LocationManager()
    @State private var memories: [Memory] = []
    /// 現在マップに適用しているフォーカス状態（ボタンのアイコン表示とシート追従時の再計算に使う）
    @State private var focusMode: FocusMode = .locationAndPins
    /// マップのカメラ位置（初期値は長野大学。データ取得後に全ピン＋現在地が収まる位置へ更新）
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: .nagano_univ, distance: 60000)
    )
    /// 現在地を含めて初期カメラを合わせたら true にして、以降の自動追従を止める
    @State private var hasCenteredWithLocation = false
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
    /// マップビュー全体の高さ（シートで隠れる領域を差し引くための基準）
    @State private var mapHeight: CGFloat = 0
    @Namespace private var mapScope

    /// 中くらいのディテントの高さ
    private static let midHeight: CGFloat = 320

    /// 検索バーだけがシート中央に収まる最小ディテントの高さ。
    /// 検索バーの実測高さ＋上下マージンで求めるので、リスト領域が0になり上下マージンが均一になる。
    private var collapsedHeight: CGFloat {
        searchBarHeight + MemoryListSheet.collapsedMargins
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

    /// 全てのピンと現在地が画面に収まるよう初期カメラ位置を更新する。
    /// 現在地を含めて一度合わせたら以降は更新せず、ユーザーの操作を妨げない。
    private func updateInitialCamera() {
        guard !hasCenteredWithLocation else { return }
        guard !memories.isEmpty else { return }

        // 無効な座標（範囲外や(0,0)）は除外する。
        // Canvas（プレビュー）では現在地が(0,0)で返り、範囲が地球規模に広がってしまうため。
        var coordinates = memories.map(\.coordinate).filter(Self.isUsable)
        if let userCoordinate = locationManager.userCoordinate, Self.isUsable(userCoordinate) {
            coordinates.append(userCoordinate)
            // 現在地まで含めて収められたので、これ以上の自動追従は止める
            hasCenteredWithLocation = true
        }

        guard let region = Self.region(enclosing: coordinates) else { return }
        withAnimation(.easeInOut) {
            cameraPosition = .region(adjustedForSheet(region, sheetTopY: sheetTopY))
        }
    }

    /// ユーザーがマップを動かして、フォーカスから外れているか
    private var isUnfocused: Bool {
        cameraPosition.positionedByUser
    }

    /// フォーカスボタンが押されたとき、次の状態へ進めてから適用する（アイコンは現在の状態を表示）。
    /// フォーカスから外れているときは状態を進めず、外れる前と同じフォーカスに戻す。
    private func cycleFocus() {
        if !isUnfocused {
            focusMode = focusMode.next
        }
        applyFocus(focusMode)
    }

    /** 指定した状態でカメラを合わせる。
        sheetTopYOverride に毎フレームの値を渡すと、吸着アニメーション中もその位置で中央を計算する。 */
    private func applyFocus(_ mode: FocusMode, animated: Bool = true, sheetTopYOverride: CGFloat? = nil) {
        switch mode {
        case .locationAndPins:
            focusCamera(includeUserLocation: true, animated: animated, sheetTopYOverride: sheetTopYOverride)
        case .pinsOnly:
            focusCamera(includeUserLocation: false, animated: animated, sheetTopYOverride: sheetTopYOverride)
        case .locationOnly:
            focusOnUserLocation(animated: animated)
        }
    }

    /// ピン（任意で現在地も）が中央に収まるようカメラを合わせる
    private func focusCamera(includeUserLocation: Bool, animated: Bool = true, sheetTopYOverride: CGFloat? = nil) {
        var coordinates = memories.map(\.coordinate).filter(Self.isUsable)
        if includeUserLocation, let user = locationManager.userCoordinate, Self.isUsable(user) {
            coordinates.append(user)
        }
        guard let region = Self.region(enclosing: coordinates) else { return }
        setCamera(.region(adjustedForSheet(region, sheetTopY: sheetTopYOverride ?? sheetTopY)), animated: animated)
    }

    /// 現在地を中央にしてフォーカスする
    private func focusOnUserLocation(animated: Bool = true) {
        guard let user = locationManager.userCoordinate, Self.isUsable(user) else { return }
        setCamera(.camera(MapCamera(centerCoordinate: user, distance: 20000)), animated: animated)
    }

    /// カメラ位置を適用する（必要ならアニメーション付き）
    private func setCamera(_ position: MapCameraPosition, animated: Bool) {
        if animated {
            withAnimation(.easeInOut) {
                cameraPosition = position
            }
        } else {
            cameraPosition = position
        }
    }

    /** シートで隠れる領域を除いた「見える範囲」の中央に内容が収まるよう region を補正する。
        シートが中ディテント(320)以下のときだけ、シートで隠れる高さぶんを描画可能領域から差し引く。
        隠れる高さは毎フレーム算出される sheetTopY から求めるので、吸着アニメーション中も滑らかに追従する。*/
    private func adjustedForSheet(_ region: MKCoordinateRegion, sheetTopY: CGFloat?) -> MKCoordinateRegion {
        guard sheetHeight <= Self.midHeight, mapHeight > 0 else { return region }
        // マップ下端(controlsAreaMaxY)とシート上端(sheetTopY)の差 = シートで隠れている高さ
        let hiddenHeight = sheetTopY.map { max(controlsAreaMaxY - $0, 0) } ?? sheetHeight
        let visibleHeight = mapHeight - hiddenHeight
        guard visibleHeight > 0 else { return region }

        // 見える範囲に内容を収めるため、緯度方向の幅を拡大する
        let scale = mapHeight / visibleHeight
        let newLatitudeDelta = region.span.latitudeDelta * scale
        // 拡大で増えたぶんのちょうど半分だけ中心を南へずらし、内容を見える範囲の中央に置く
        let newCenterLatitude = region.center.latitude - region.span.latitudeDelta / 2 * (scale - 1)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: newCenterLatitude,
                longitude: region.center.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: newLatitudeDelta,
                longitudeDelta: region.span.longitudeDelta
            )
        )
    }

    /// フィット計算に使える座標か（範囲内で、かつ(0,0)でない）
    private nonisolated static func isUsable(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        return !(coordinate.latitude == 0 && coordinate.longitude == 0)
    }

    /// 与えられた座標群をすべて含む、余白付きの領域を求める
    private static func region(enclosing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }

        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // 1.4倍の余白を取り、1点しかない場合でも最低限の広さを確保する
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4 + 0.01,
            longitudeDelta: (maxLon - minLon) * 1.4 + 0.01
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        Map(position: $cameraPosition, scope: mapScope) {
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
                    // マップ全体の高さを計測（シートで隠れる領域を除くための基準）
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        mapHeight = newHeight
                    }

                VStack(spacing: 12) {
                    // 押すたびに「現在地とピン→ピン全体→現在地」と循環してフォーカスする。
                    // 長押しするとメニューからモードを直接選べる
                    Menu {
                        Picker("フォーカス", selection: Binding(
                            get: { focusMode },
                            set: { newMode in
                                focusMode = newMode
                                applyFocus(newMode)
                            }
                        )) {
                            ForEach(FocusMode.allCases, id: \.self) { mode in
                                Label(mode.title, systemImage: mode.iconName)
                                    .tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: focusMode.iconName)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                    } primaryAction: {
                        cycleFocus()
                    }
                    // フォーカスから外れている間はグレーにする
                    .tint(isUnfocused ? .gray : nil)
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
        // ピンの取得・現在地の更新に合わせて初期カメラを「全ピン＋現在地が収まる」位置へ合わせる
        .onChange(of: memories.count) { _, _ in
            updateInitialCamera()
        }
        .onChange(of: locationManager.userCoordinate?.latitude) { _, _ in
            updateInitialCamera()
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
                            // 毎フレームの上端位置で中央を再計算し、吸着アニメーション中も滑らかに追従させる。
                            // ユーザーがマップを動かして別の場所を見ている間は、勝手にフォーカスへ戻さない
                            // （フォーカスボタンを押すとカメラがコードから設定され、追従が再開する）
                            if !isUnfocused {
                                applyFocus(focusMode, animated: false, sheetTopYOverride: newTopY)
                            }
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

//
//  MemoryListSheet.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/08.
//

import SwiftUI

/// === 思い出の場所リスト（下から出てくるシート）===
struct MemoryListSheet: View {
    let memories: [Memory]
    @Binding var searchText: String
    /// 計測した検索バー（ピル）の高さを親へ返す
    @Binding var searchBarHeight: CGFloat
    /// 検索バーがフォーカスされているか
    @FocusState private var isSearchFocused: Bool
    /// 現在のシート（コンテンツ）の高さを親へ返す
    @Binding var sheetHeight: CGFloat
    /// ユーザーボタンが押されたときの処理（遷移先は親で決める）
    var onUserButtonTap: () -> Void = {}

    /// 検索バー周りの均一マージン（上下で共通）
    static let searchBarMargin: CGFloat = 12
    /// 最小ディテント時に検索バー以外で確保する高さ（上下マージンの合計）。
    /// 下側はセーフエリアを無視して手動で余白を取っているぶん上側が詰まって見えるので、2倍より多めに取る。
    static let collapsedMargins: CGFloat = searchBarMargin * 2.5

    /// 最小ディテント（検索バーだけ）より大きく開いているか。
    /// 最小時はリストを隠して、検索バーのガラスにリスト内容が透けないようにする。
    private var isExpanded: Bool {
        sheetHeight > searchBarHeight + Self.collapsedMargins + 8
    }

    /// 検索バー横のボタンを出すか（最小時、または検索中）
    private var showsSideButton: Bool {
        isSearchFocused || !isExpanded
    }

    /// 円形ガラスボタンのアイコン（検索バーと同じ高さ）
    private func circleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.secondary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: searchBarHeight, height: searchBarHeight)
            .contentShape(Circle())
    }

    /// 検索テキストで絞り込んだ一覧
    private var filteredMemories: [Memory] {
        guard !searchText.isEmpty else { return memories }
        return memories.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 場所一覧（検索バーの裏まで表示し、ガラス越しに透けさせる）
            List(filteredMemories) { memory in
                Text(memory.name)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // 末尾の行が検索バーに隠れ続けないよう、下に検索バーぶんの余白を確保
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: searchBarHeight + Self.searchBarMargin * 2)
            }
            // 引き延ばした時のヘッダー（右側にアカウントボタン）
            // 最小時に置くとヘッダーぶん高さがはみ出し、検索バーが下へ押し出されるので、引き延ばした時だけ置く
            .safeAreaBar(edge: .top) {
                if isExpanded {
                    HStack {
                        Text("みんなの思い出一覧")
                            .font(.title2.bold())
                        Spacer()
                        Button(action: onUserButtonTap) {
                            circleIcon("person.fill")
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .accessibilityLabel("アカウント")
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                }
            }
            // ヘッダーぶんシートより背が高くなっても、計測するシートの高さが実際の高さからずれないようにする
            // （ずれると最小化しても「引き延ばし中」と判定され、ヘッダーが残って検索バーが押し出される）
            .frame(minHeight: 0, maxHeight: .infinity)
            // 最小時はリストを隠し、検索バーのガラスに内容が透けないようにする
            .opacity(isExpanded ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isExpanded)

            // 検索バー＋ユーザーボタン（リストの前面にオーバーレイ・上下マージン均一）
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    // 検索バー
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("思い出を検索", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isSearchFocused)
                        if isSearchFocused {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 25))
                    // ピル自体の高さを計測して親へ返す（最小ディテントの算出に使う）
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        searchBarHeight = newHeight
                    }

                    // 検索バー横のボタン（最小時はアカウント、検索中はバツ）
                    // 引き延ばした時はアカウントボタンがヘッダーへ移るので、検索中以外は隠す
                    if showsSideButton {
                        Button {
                            if isSearchFocused {
                                isSearchFocused = false
                            } else {
                                onUserButtonTap()
                            }
                        } label: {
                            circleIcon(isSearchFocused ? "xmark" : "person.fill")
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .accessibilityLabel(isSearchFocused ? "検索をやめる" : "アカウント")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showsSideButton)
            .padding(.horizontal)
            .padding(.bottom, Self.searchBarMargin * 1.25)
        }
        // 下部セーフエリアを無視し、検索バー下の余白を上側と同じ値で手動指定して均一にする
        .ignoresSafeArea(.container, edges: .bottom)
        // シートの高さを計測し、最小かどうかの判定に使う
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            sheetHeight = newHeight
        }
    }
}

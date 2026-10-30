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

    /// 検索バー周りの均一マージン（上下で共通）
    static let searchBarMargin: CGFloat = 12

    /// 最小ディテント（検索バーだけ）より大きく開いているか。
    /// 最小時はリストを隠して、検索バーのガラスにリスト内容が透けないようにする。
    private var isExpanded: Bool {
        sheetHeight > searchBarHeight + Self.searchBarMargin * 2 + 8
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
            // 最小時はリストを隠し、検索バーのガラスに内容が透けないようにする
            .opacity(isExpanded ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isExpanded)

            // 検索バー（リストの前面にオーバーレイ・上下マージン均一）
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("場所を検索", text: $searchText)
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

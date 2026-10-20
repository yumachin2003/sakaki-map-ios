//
//  FestivalService.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/19.
//

import Foundation

/// 祭りデータの取得を担当するサービス
enum FestivalService {
    private static let endpoint = "https://shinshu-fesnav.sekilab.org/api/festivals"

    /// APIから祭りデータを取得して返す
    static func fetchFestivals() async throws -> [Festival] {
        guard let url = URL(string: endpoint) else { return [] }

        // 【一時回避】サーバーの証明書が期限切れのため、検証をバイパスするセッションを使用
        let (data, _) = try await InsecureURLSession.shared.data(from: url)

        return try JSONDecoder().decode([Festival].self, from: data)
    }
}

// ============================================================================
// ⚠️ 一時回避コード：サーバーの証明書が期限切れのための暫定対応
// ----------------------------------------------------------------------------
// サーバー側の証明書が更新されたら、このブロックごと丸ごと削除し、
// fetchFestivals() 内の `InsecureURLSession.shared` を `URLSession.shared` に戻す。
// （本番運用では証明書検証を無効化したままにしないこと）
// ============================================================================
/// 証明書検証をスキップする URLSession（開発用）
enum InsecureURLSession {
    static let shared: URLSession = {
        URLSession(
            configuration: .default,
            delegate: InsecureSessionDelegate(),
            delegateQueue: nil
        )
    }()
}

private final class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // サーバー信頼評価のチャレンジを無条件に受け入れる（証明書検証を無効化）
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}
// ============================================================================
// ⚠️ 一時回避コードここまで
// ============================================================================

//
//  SheetTopReader.swift
//  sakaki-map-ios
//
//  Created by Yuma on 2026/10/08.
//

import SwiftUI
import UIKit

/// === シート上端の位置をフレームごとに求めるビュー ===
/// シートのドラッグや吸着アニメーションはUIKit（Core Animation）側で動いており、
/// SwiftUIには最終的な高さしか届かない。そこで UIUpdateLink を使い、各フレームの描画直前に
/// 「このフレームが画面に表示される瞬間、シートの上端がどこにあるか」を計算してボタン側へ伝える。
struct SheetTopReader: UIViewRepresentable {
    /// 新しいシート上端のY座標（ウィンドウ座標）
    var onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: TrackingView, context: Context) {
        uiView.onChange = onChange
    }

    final class TrackingView: UIView {
        var onChange: ((CGFloat) -> Void)?
        private var updateLink: UIUpdateLink?
        private var lastTopY: CGFloat?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // ウィンドウから外れている間は UIUpdateLink が自動で止まる
            guard window != nil, updateLink == nil else { return }
            let link = UIUpdateLink(view: self)
            // タッチやレイアウトで画面が更新されるフレームごとに、描画の直前で呼ばれる
            link.addAction(to: .beforeCATransactionCommit) { [weak self] link, info in
                self?.update(link, info)
            }
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
            link.isEnabled = true
            updateLink = link
        }

        private func update(_ link: UIUpdateLink, _ info: UIUpdateInfo) {
            guard let window else { return }
            // シートの位置はレイアウト時に決まるので、先にレイアウトを済ませてから読む
            window.layoutIfNeeded()
            let (topY, isAnimating) = displayedTopY(at: info.estimatedPresentationTime)
            // シートがアニメーションしている間だけ、毎フレーム呼んでもらう
            link.requiresContinuousUpdates = isAnimating

            guard lastTopY.map({ abs(topY - $0) >= 0.1 }) ?? true else { return }
            lastTopY = topY
            onChange?(topY)
        }

        /// 時刻 time に、このビューの上端（＝シートの上端）が画面のどこに表示されるか。
        /// レイアウト上の位置に、親レイヤーたちで動いているアニメーションのずれを足して求める。
        /// （presentation layer は1フレーム前の値しか返さないため、Core Animation と同じ計算を自前で行う）
        private func displayedTopY(at time: CFTimeInterval) -> (CGFloat, Bool) {
            var topY = layer.convert(CGPoint.zero, to: nil).y
            var isAnimating = false
            var current: CALayer? = layer
            while let target = current {
                for key in target.animationKeys() ?? [] {
                    guard let animation = target.animation(forKey: key) as? CABasicAnimation,
                          let progress = animation.progress(at: time) else { continue }
                    switch animation.keyPath {
                    case "position":
                        // 位置が動くと、上端もそのまま動く
                        if let offset = animation.offset(progress, model: target.position.y, { ($0 as? NSValue)?.cgPointValue.y }) {
                            topY += offset
                            isAnimating = true
                        }
                    case "bounds.size":
                        // 中心を基準に高さが変わると、上端は高さの変化 × anchorPoint.y だけ逆向きに動く
                        if let offset = animation.offset(progress, model: target.bounds.height, { ($0 as? NSValue)?.cgSizeValue.height }) {
                            topY -= offset * target.anchorPoint.y
                            isAnimating = true
                        }
                    default:
                        continue
                    }
                }
                current = target.superlayer
            }
            return (topY, isAnimating)
        }
    }
}

private extension CABasicAnimation {
    /// 時刻 time におけるアニメーションの進み具合（0 → 1）。終わっていれば nil
    func progress(at time: CFTimeInterval) -> Double? {
        // beginTime は描画時に決まるので、0 ならこのフレームで追加されたもの（＝いま始まる）
        let start = beginTime > 0 ? beginTime : CACurrentMediaTime()
        let length = duration > 0 ? duration : 0.25
        let elapsed = time - start
        guard elapsed < length else { return nil }
        guard elapsed > 0 else { return 0 }
        if let spring = self as? CASpringAnimation {
            return 1 - SheetTopReader.SpringCurve(spring).remaining(at: elapsed)
        }
        let linear = elapsed / length
        return timingFunction?.value(at: linear) ?? linear
    }

    /// 進み具合 progress のときに、レイアウト上の値からどれだけずれて表示されるか
    func offset(_ progress: Double, model: CGFloat, _ value: (Any?) -> CGFloat?) -> CGFloat? {
        guard let from = value(fromValue), let to = value(toValue) else { return nil }
        let current = from + (to - from) * progress
        // additive（UIKitのアニメーションは基本これ）は「ずれ」そのもの、そうでなければ実際の値
        return isAdditive ? current : current - model
    }
}

private extension CAMediaTimingFunction {
    /// イージング曲線（3次ベジェ）で、時間の割合 x に対する進み具合を求める
    func value(at x: Double) -> Double {
        var p1: [Float] = [0, 0]
        var p2: [Float] = [0, 0]
        getControlPoint(at: 1, values: &p1)
        getControlPoint(at: 2, values: &p2)
        func bezier(_ t: Double, _ a: Float, _ b: Float) -> Double {
            let a = Double(a), b = Double(b)
            return 3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t
        }
        // x になる t を二分探索で求めてから、そのときの y を返す
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let mid = (low + high) / 2
            if bezier(mid, p1[0], p2[0]) < x { low = mid } else { high = mid }
        }
        return bezier((low + high) / 2, p1[1], p2[1])
    }
}

extension SheetTopReader {
    /// Core Animation のばね（CASpringAnimation）と同じ式で動きを計算する
    struct SpringCurve {
        let mass: Double
        let stiffness: Double
        let damping: Double
        let initialVelocity: Double

        init(_ spring: CASpringAnimation) {
            mass = spring.mass
            stiffness = spring.stiffness
            damping = spring.damping
            initialVelocity = spring.initialVelocity
        }

        /// 開始から t 秒後に、移動距離のうちどれだけ残っているか（開始時 1 → 終了時 0）
        func remaining(at t: Double) -> Double {
            let omega = (stiffness / mass).squareRoot()
            let zeta = damping / (2 * (stiffness * mass).squareRoot())
            let v0 = initialVelocity
            if zeta < 1 {
                // 減衰振動（少し行き過ぎて戻る）
                let omegaD = omega * (1 - zeta * zeta).squareRoot()
                return exp(-zeta * omega * t)
                    * (cos(omegaD * t) + (zeta * omega - v0) / omegaD * sin(omegaD * t))
            } else if zeta == 1 {
                // 臨界減衰（行き過ぎずに最短で止まる）
                return exp(-omega * t) * (1 + (omega - v0) * t)
            } else {
                // 過減衰（ゆっくり止まる）
                let root = (zeta * zeta - 1).squareRoot()
                let r1 = -omega * (zeta - root)
                let r2 = -omega * (zeta + root)
                let a = (-v0 - r2) / (r1 - r2)
                return a * exp(r1 * t) + (1 - a) * exp(r2 * t)
            }
        }
    }
}

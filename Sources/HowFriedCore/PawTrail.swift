import Foundation

public struct Footprint {
    public let step: Int
    public let x: Double
    public let lane: Int
    public let facingRight: Bool
    public let opacity: Double
    public let rotationDegrees: Double
}

/// Planted alternating footsteps: positions never slide during a print's lifetime.
public enum PawTrail {
    public static func samples(elapsed: Double, width: Double, deadZone: Double = 0) -> [Footprint] {
        func positions(_ start: Double, _ end: Double) -> [Double] {
            guard end > start else { return [] }
            let count = max(1, Int((end-start)/24))
            return (0...count).map { start + Double($0) * (end-start) / Double(count) }
        }
        let wing = (width-deadZone)/2
        // Every centre clears the clipping boundary by a full rotated paw radius.
        let xs = deadZone > 0
            ? positions(72, wing-18) + positions(wing+deadZone+18, width-72)
            : positions(20, width-20)
        guard xs.count >= 2 else { return [] }
        let route = Array(xs.indices) + Array(xs.indices.dropFirst().dropLast().reversed())
        var times = [0.0]
        for i in 1..<route.count {
            let crosses = deadZone > 0 && (xs[route[i-1]] < width/2) != (xs[route[i]] < width/2)
            times.append(times.last! + (crosses ? 1.0 : 0.48))
        }
        let duration = times.last! + 0.48
        let time = max(0, elapsed), cycle = Int(time / duration)
        var result: [Footprint] = []
        for lap in max(0, cycle-1)...cycle {
            for i in route.indices {
                let age = time - (Double(lap)*duration + times[i])
                guard age >= 0, age < 0.82 else { continue }
                let opacity = min(1, age/0.12) * max(0, 1-max(0, age-0.42)/0.40)
                guard opacity > 0 else { continue }
                let step = lap*route.count+i, lane = step % 2
                let forward = i < xs.count-1
                let splay = [24.0, 29, 26, 32, 27, 30][step % 6]
                let angle = (forward ? 90.0 : -90.0) + (lane == 0 ? -splay : splay) * (forward ? 1 : -1)
                result.append(Footprint(step: step, x: xs[route[i]], lane: lane, facingRight: forward,
                                        opacity: opacity, rotationDegrees: angle))
            }
        }
        return result
    }
}

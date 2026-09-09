import Foundation

/// Small original piano-like arpeggio. No recordings, downloads, licensing or API dependencies.
public enum CalmScore {
    public static let titles = ["Window seat", "Slow Sunday", "After hours"]
    public static func wave(variant: Int = 0) -> Data {
        let rate = 22050, seconds = 16, count = rate * seconds
        let shift = [0, -2, 3][abs(variant % 3)]
        let chords = [[48,55,59,64], [45,52,55,60], [50,57,60,65], [43,50,57,59]]
        var samples = [Double](repeating: 0, count: count)
        for beat in 0..<32 {
            let chord = chords[(beat/8)%4]
            let midi = chord[[0,2,1,3][beat%4]] + shift + (beat%4 == 3 ? 12 : 0)
            let frequency = 440 * pow(2, Double(midi-69)/12)
            let start = Int(Double(beat)*0.5*Double(rate))
            for offset in 0..<(rate*3) {
                let t = Double(offset)/Double(rate)
                let attack = min(1, t/0.018)
                let decay = exp(-t*2.0)
                let wave = sin(2 * .pi * frequency * t) + 0.24*sin(2 * .pi * frequency*2*t) + 0.06*sin(2 * .pi * frequency*3*t)
                // Wrap decays into the start of the loop to avoid an abrupt loop boundary.
                samples[(start+offset)%count] += wave*attack*decay*0.115
            }
        }
        var data = Data()
        func text(_ s: String) { data.append(contentsOf: s.utf8) }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36+count*2)); text("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate*2)); u16(2); u16(16); text("data"); u32(UInt32(count*2))
        for sample in samples { u16(UInt16(bitPattern: Int16(max(-0.95, min(0.95, sample))*32767))) }
        return data
    }
}

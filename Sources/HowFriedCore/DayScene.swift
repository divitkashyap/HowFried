import Foundation

/// Local-clock art direction, not an astronomical sunrise/sunset calculation.
public struct DayScene {
    public let hour: Double
    public init(hour: Double) { self.hour = min(23.999, max(0, hour)) }
    public var isNight: Bool { hour < 7 || hour >= 19 }
    public var sunX: Double { 0.18 + min(1, max(0, (hour-7)/12)) * 0.64 }
    public var sunY: Double { 0.27 - sin(min(1, max(0, (hour-7)/12)) * .pi) * 0.15 }
    public static func local(date: Date = Date(), calendar: Calendar = .current) -> Self {
        Self(hour: Double(calendar.component(.hour, from: date)) + Double(calendar.component(.minute, from: date))/60)
    }
}

import Foundation

extension Date {
    /// Kort norsk relativ tidsangivelse: "nå", "3 min siden", "2t siden", "5d siden".
    var timeAgoNorwegian: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "nå" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) min siden"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)t siden"
        }
        let days = Int(interval / 86400)
        return "\(days)d siden"
    }
}

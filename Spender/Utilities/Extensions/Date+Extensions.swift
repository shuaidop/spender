import Foundation

extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    var endOfWeek: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    var endOfMonth: Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return self
        }
        return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? self
    }

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

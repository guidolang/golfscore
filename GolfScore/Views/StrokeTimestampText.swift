import SwiftUI

struct StrokeTimestampText: View {
    let date: Date

    var body: some View {
        Text(StrokeTimestampFormatter.string(for: date))
    }
}

enum StrokeTimestampFormatter {
    static func string(
        for date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = uses24HourTime(locale: locale)
            ? "yyyy-MM-dd HH:mm"
            : "yyyy-MM-dd hh:mm a"
        return formatter.string(from: date)
    }

    private static func uses24HourTime(locale: Locale) -> Bool {
        let hourFormat = DateFormatter.dateFormat(
            fromTemplate: "j",
            options: 0,
            locale: locale
        ) ?? "h a"
        return !hourFormat.contains("a")
    }
}

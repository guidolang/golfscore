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
        relativeTo referenceDate: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.isDate(date, inSameDayAs: referenceDate)
            ? "h:mm a"
            : "MM/dd/yyyy h:mm a"
        return formatter.string(from: date)
    }
}

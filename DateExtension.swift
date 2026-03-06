import Foundation

extension Date {
    nonisolated(unsafe) static var firstDayOfWeek = Calendar.current.firstWeekday

    static var capitalizedFirstLettersOfWeekdays: [String] {
        let calendar = Calendar.current
        let weekdays = calendar.shortWeekdaySymbols
        let offset = firstDayOfWeek - 1
        return (0..<7).map { weekdays[($0 + offset) % 7].capitalized }
    }

    static var fullMonthNames: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return (1...12).compactMap { month in
            Calendar.current.date(from: DateComponents(year: 2000, month: month, day: 1))
                .map { formatter.string(from: $0) }
        }
    }

    var startOfMonth: Date {
        Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: self)
        )!
    }

    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
    }

    var startOfPreviousMonth: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: startOfMonth)!
    }

    var numberOfDaysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)!.count
    }

    var firstWeekDayBeforeStart: Date {
        let startWeekday = Calendar.current.component(.weekday, from: startOfMonth)
        var offset = (startWeekday - Self.firstDayOfWeek + 7) % 7
        return Calendar.current.date(byAdding: .day, value: -offset, to: startOfMonth)!
    }

    var calendarDisplayDays: [Date] {
        let totalDays = Calendar.current.dateComponents(
            [.day], from: firstWeekDayBeforeStart, to: startOfMonth
        ).day! + numberOfDaysInMonth

        return (0..<totalDays).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: firstWeekDayBeforeStart)
        }
    }

    var yearInt: Int {
        Calendar.current.component(.year, from: self)
    }

    var monthInt: Int {
        Calendar.current.component(.month, from: self)
    }

    var dayInt: Int {
        Calendar.current.component(.day, from: self)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var randomDateWithinLastThreeMonths: Date {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: self)!
        let range = threeMonthsAgo..<self
        let randomInterval = TimeInterval.random(in: 0..<timeIntervalSince(threeMonthsAgo))
        return threeMonthsAgo.addingTimeInterval(randomInterval)
    }
}

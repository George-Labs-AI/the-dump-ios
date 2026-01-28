import SwiftUI

//Thin routing layer. Receives kin (category, dategroup, or mimetype), name, count. Only job is to translate thos into the correct NotesListViewModel.Filter and pass it to NotesListView. For date roups, this is where DateGroupRangeBuilder computes the date range. 

struct BrowseFolderDestinationView: View {
    enum Kind {
        case category
        case dateGroup
        case mimeType
        
        var titlePrefix: String {
            switch self {
            case .category: return "Category"
            case .dateGroup: return "Date Group"
            case .mimeType: return "Mime Type"
            }
        }
    }
    
    let kind: Kind
    let name: String
    let count: Int
    
    var body: some View {
        NotesListView(title: name, filter: notesFilter)
    }
    
    private var notesFilter: NotesListViewModel.Filter {
        switch kind {
        case .category:
            return .category(name: name)
        case .mimeType:
            return .mimeType(name)
        case .dateGroup:
            let (start, end) = DateGroupRangeBuilder.range(for: name)
            return .dateGroup(name: name, startTime: start, endTime: end)
        }
    }
}

#Preview {
    NavigationStack {
        BrowseFolderDestinationView(kind: .category, name: "Work", count: 12)
    }
}

private enum DateGroupRangeBuilder {
    /// Returns `start_time` and `end_time` in backend-expected `YYYY-MM-DD` local date strings.
    /// For "All Time" (or unknown), returns empty strings to indicate "no date filter".
    static func range(for dateGroupName: String) -> (startDate: String, endDate: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        
        // Backend expectation (per API dev): Postgres week starts Monday.
        calendar.firstWeekday = 2
        
        let now = Date()
        
        func yyyyMmDd(_ date: Date) -> String {
            let df = DateFormatter()
            df.calendar = calendar
            df.locale = calendar.locale
            df.timeZone = calendar.timeZone
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: date)
        }
        
        func startOfDay(_ date: Date) -> Date {
            calendar.startOfDay(for: date)
        }
        
        let today = startOfDay(now)
        
        switch dateGroupName {
        case "Today":
            let d = yyyyMmDd(today)
            return (d, d)
        case "Yesterday":
            let y = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let d = yyyyMmDd(y)
            return (d, d)
        case "This Week":
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return (yyyyMmDd(weekStart), yyyyMmDd(today))
        case "This Month":
            let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
            return (yyyyMmDd(monthStart), yyyyMmDd(today))
        case "This Year":
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            return (yyyyMmDd(yearStart), yyyyMmDd(today))
        case "All Time":
            return ("", "")
        default:
            return ("", "")
        }
    }
}




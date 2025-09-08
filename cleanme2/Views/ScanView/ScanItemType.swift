import UIKit

enum ScanItemType: CaseIterable {
    case contacts, calendar, similar, duplicates, blurred, screenshots, videos

    var title: String {
        switch self {
        case .contacts:
            "Contacts"
        case .calendar:
            "Calendar"
        case .similar:
            "Similar"
        case .duplicates:
            "Duplicates"
        case .blurred:
            "Blurred"
        case .screenshots:
            "Screenshots"
        case .videos:
            "Videos"
        }
    }
}

import Foundation

enum FormatChoice {
    private static let key = "hasChosenFormat"

    static var hasChosen: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

extension Notification.Name {
    static let gutenkernResetProgress = Notification.Name("gutenkern.resetProgress")
}

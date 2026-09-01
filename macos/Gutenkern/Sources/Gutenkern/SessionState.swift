import AppKit
import Combine
import Foundation
import GutenkernCore

final class SessionState: ObservableObject {
    static let shared = SessionState()

    private static let defaultsKey = "sessionSnapshot"
    private static let debounce: TimeInterval = 0.3

    @Published var field1: String
    @Published var field2: String
    @Published var selectedGroups: Set<KerningGroup>
    @Published var completedRecipes: Set<String>
    @Published var mode: PairMode
    @Published var format: OutputFormat

    private var cancellables = Set<AnyCancellable>()
    private var persistWorkItem: DispatchWorkItem?
    private var terminateObserver: NSObjectProtocol?

    private init() {
        let snapshot = Self.load()
        field1 = snapshot.field1
        field2 = snapshot.field2
        selectedGroups = snapshot.selectedGroups
        completedRecipes = snapshot.completedRecipeSet
        mode = snapshot.pairMode
        format = snapshot.outputFormat
        observeChanges()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistNow()
        }
    }

    func persistNow() {
        persistWorkItem?.cancel()
        persistWorkItem = nil
        save()
    }

    private func observeChanges() {
        bind($field1)
        bind($field2)
        bind($selectedGroups)
        bind($completedRecipes)
        bind($mode)
        bind($format)
    }

    private func bind<T>(_ publisher: Published<T>.Publisher) {
        publisher
            .dropFirst()
            .sink { [weak self] _ in
                self?.schedulePersist()
            }
            .store(in: &cancellables)
    }

    private func schedulePersist() {
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.save()
        }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }

    private func snapshot() -> SessionSnapshot {
        SessionSnapshot.make(
            field1: field1,
            field2: field2,
            selectedGroups: selectedGroups,
            completedRecipes: completedRecipes,
            mode: mode,
            format: format
        )
    }

    private func save() {
        guard let data = snapshot().encoded() else {
            return
        }
        try? FileManager.default.createDirectory(
            at: Self.directoryURL,
            withIntermediateDirectories: true
        )
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private static func load() -> SessionSnapshot {
        if let data = try? Data(contentsOf: fileURL) {
            return SessionSnapshot.decoded(from: data)
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            return SessionSnapshot.decoded(from: data)
        }
        return .empty
    }

    private static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gutenkern", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("session.json")
    }
}

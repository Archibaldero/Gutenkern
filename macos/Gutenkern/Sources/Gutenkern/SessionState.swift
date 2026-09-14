import AppKit
import Combine
import Foundation
import GutenkernCore

final class SessionState: ObservableObject {
    static let shared = SessionState()

    private static let defaultsKey = "sessionSnapshot"
    private static let debounce: TimeInterval = 0.3

    @Published var field1: String
    @Published var completedRecipes: Set<String>
    @Published var completedBlocks: Set<String>
    @Published var format: OutputFormat

    var hasProgress: Bool {
        !completedBlocks.isEmpty || !completedRecipes.isEmpty
    }

    private var cancellables = Set<AnyCancellable>()
    private var persistWorkItem: DispatchWorkItem?
    private var terminateObserver: NSObjectProtocol?

    private init() {
        let loaded = Self.load()
        if loaded.existed {
            FormatChoice.hasChosen = true
            field1 = loaded.snapshot.field1
        } else {
            field1 = SessionSnapshot.defaultGlyphs
        }
        completedRecipes = loaded.snapshot.completedRecipeSet
        completedBlocks = loaded.snapshot.completedBlockSet
        format = loaded.snapshot.outputFormat
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
        bind($completedRecipes)
        bind($completedBlocks)
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
            completedRecipes: completedRecipes,
            completedBlocks: completedBlocks,
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

    func resetProgress() {
        completedRecipes = []
        completedBlocks = []
    }

    private static func load() -> (snapshot: SessionSnapshot, existed: Bool) {
        if let data = try? Data(contentsOf: fileURL) {
            return (SessionSnapshot.decoded(from: data), true)
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            return (SessionSnapshot.decoded(from: data), true)
        }
        return (.empty, false)
    }

    private static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gutenkern", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("session.json")
    }
}

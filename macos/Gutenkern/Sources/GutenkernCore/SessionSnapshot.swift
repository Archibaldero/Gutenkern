import Foundation

public struct SessionSnapshot: Equatable, Sendable, Codable {
    public var field1: String
    public var field2: String
    public var groups: [String]
    public var completedRecipes: [String]
    public var mode: String
    public var format: String

    public static let empty = SessionSnapshot()

    public init(
        field1: String = "",
        field2: String = "",
        groups: [String] = [],
        completedRecipes: [String] = [],
        mode: String = PairMode.simple.rawValue,
        format: String = OutputFormat.fontlab.rawValue
    ) {
        self.field1 = field1
        self.field2 = field2
        self.groups = groups
        self.completedRecipes = completedRecipes
        self.mode = mode
        self.format = format
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        field1 = try container.decodeIfPresent(String.self, forKey: .field1) ?? ""
        field2 = try container.decodeIfPresent(String.self, forKey: .field2) ?? ""
        groups = try container.decodeIfPresent([String].self, forKey: .groups) ?? []
        completedRecipes = try container.decodeIfPresent([String].self, forKey: .completedRecipes) ?? []
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? PairMode.simple.rawValue
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? OutputFormat.fontlab.rawValue
    }

    public var completedRecipeSet: Set<String> {
        Set(completedRecipes)
    }

    public var outputFormat: OutputFormat {
        OutputFormat(rawValue: format) ?? .fontlab
    }

    public var pairMode: PairMode {
        PairMode(rawValue: mode) ?? .simple
    }

    public func sanitized() -> SessionSnapshot {
        Self.make(
            field1: field1,
            completedRecipes: completedRecipeSet,
            format: outputFormat
        )
    }

    public static func make(
        field1: String,
        completedRecipes: Set<String>,
        format: OutputFormat
    ) -> SessionSnapshot {
        SessionSnapshot(
            field1: field1,
            field2: "",
            groups: [],
            completedRecipes: completedRecipes.filter { !$0.isEmpty }.sorted(),
            mode: PairMode.simple.rawValue,
            format: format.rawValue
        )
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(sanitized())
    }

    public static func decoded(from data: Data) -> SessionSnapshot {
        (try? JSONDecoder().decode(SessionSnapshot.self, from: data))?.sanitized() ?? .empty
    }
}

import Foundation
import GutenkernCore

@main
struct GutenkernCoreCheck {
    static func main() throws {
        let fixturesURL = try resolveFixturesURL()
        let data = try Data(contentsOf: fixturesURL)
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: data)
        var failures = 0

        if fixtures.parse.isEmpty
            || fixtures.generate.isEmpty
            || fixtures.plan.isEmpty
            || fixtures.classify.isEmpty
            || fixtures.generateAll.isEmpty
        {
            fputs("fixtures.json has no cases\n", stderr)
            exit(1)
        }

        for testCase in fixtures.parse {
            let parsed = KerningGenerator.parse(testCase.input)
            let actual = parsed.map { glyph -> [String: String] in
                switch glyph {
                case .character(let character):
                    return ["type": "character", "value": String(character)]
                case .name(let name):
                    return ["type": "name", "value": name]
                }
            }
            let expected = testCase.glyphs.map { ["type": $0.type, "value": $0.value] }
            if actual != expected {
                fputs("PARSE FAIL \(testCase.id)\n  expected: \(expected)\n  actual:   \(actual)\n", stderr)
                failures += 1
            }
        }

        for testCase in fixtures.generate {
            guard let mode = PairMode(rawValue: testCase.mode) else {
                fputs("GENERATE FAIL \(testCase.id): unknown mode \(testCase.mode)\n", stderr)
                failures += 1
                continue
            }
            guard let format = OutputFormat(rawValue: testCase.format) else {
                fputs("GENERATE FAIL \(testCase.id): unknown format \(testCase.format)\n", stderr)
                failures += 1
                continue
            }
            let actual = KerningGenerator.generate(
                left: testCase.left,
                right: testCase.right,
                mode: mode,
                format: format
            )
            if actual != testCase.expected {
                fputs(
                    "GENERATE FAIL \(testCase.id)\n  expected:\n\(testCase.expected)\n  actual:\n\(actual)\n",
                    stderr
                )
                failures += 1
            }
        }

        for testCase in fixtures.plan {
            var selected = Set<KerningGroup>()
            var unknown = false
            for code in testCase.selected {
                guard let group = KerningGroup(rawValue: code) else {
                    fputs("PLAN FAIL \(testCase.id): unknown group \(code)\n", stderr)
                    failures += 1
                    unknown = true
                    break
                }
                selected.insert(group)
            }
            if unknown {
                continue
            }
            let actual = KerningPlan.text(selected: selected)
            if actual != testCase.expected {
                fputs(
                    "PLAN FAIL \(testCase.id)\n  expected:\n\(testCase.expected)\n  actual:\n\(actual)\n",
                    stderr
                )
                failures += 1
            }
        }

        for testCase in fixtures.classify {
            let classified = GlyphClassifier.classify(testCase.input)
            let groups = classified.groups.map(\.rawValue)
            let unknown = classified.unknown.map { token -> String in
                switch token.glyph {
                case .character(let character):
                    return String(character)
                case .name(let name):
                    return name
                }
            }
            if groups != testCase.groups || unknown != testCase.unknown {
                fputs(
                    "CLASSIFY FAIL \(testCase.id)\n  expected groups: \(testCase.groups) unknown: \(testCase.unknown)\n  actual groups:   \(groups) unknown: \(unknown)\n",
                    stderr
                )
                failures += 1
            }
        }

        for testCase in fixtures.generateAll {
            guard let format = OutputFormat(rawValue: testCase.format) else {
                fputs("GENERATEALL FAIL \(testCase.id): unknown format \(testCase.format)\n", stderr)
                failures += 1
                continue
            }
            let actual = KerningGenerator.generate(testCase.input, format: format)
            if actual != testCase.expected {
                fputs(
                    "GENERATEALL FAIL \(testCase.id)\n  expected:\n\(testCase.expected)\n  actual:\n\(actual)\n",
                    stderr
                )
                failures += 1
            }
        }

        if failures > 0 {
            fputs("\(failures) fixture(s) failed\n", stderr)
            exit(1)
        }

        failures += runSessionSnapshotChecks()
        if failures > 0 {
            fputs("\(failures) session snapshot check(s) failed\n", stderr)
            exit(1)
        }

        let fixtureCount = fixtures.parse.count
            + fixtures.generate.count
            + fixtures.plan.count
            + fixtures.classify.count
            + fixtures.generateAll.count
        print("All \(fixtureCount) fixtures passed")
    }

    private static func resolveFixturesURL() throws -> URL {
        if CommandLine.arguments.count > 1 {
            return URL(fileURLWithPath: CommandLine.arguments[1])
        }

        var directories = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        ]

        while let directory = directories.first {
            directories.removeFirst()
            let candidate = directory.appendingPathComponent("core/fixtures.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path != directory.path {
                directories.append(parent)
            }
        }

        throw CheckError.fixturesNotFound
    }
}

private func runSessionSnapshotChecks() -> Int {
    var failures = 0

    let dirty = SessionSnapshot(
        field1: "AV",
        field2: "ignored",
        groups: ["A", "unknown", "a"],
        completedRecipes: ["A/A/A", "", "a/a/a"],
        mode: "mirror",
        format: "glyphs"
    ).sanitized()
    if dirty.field1 != "AV" || !dirty.field2.isEmpty || !dirty.groups.isEmpty {
        fputs("SESSION FAIL field/groups: \(dirty.field1) \(dirty.field2) \(dirty.groups)\n", stderr)
        failures += 1
    }
    if dirty.completedRecipes != ["A/A/A", "a/a/a"] {
        fputs("SESSION FAIL recipes: \(dirty.completedRecipes)\n", stderr)
        failures += 1
    }
    if dirty.pairMode != .simple || dirty.outputFormat != .glyphs {
        fputs("SESSION FAIL mode/format: \(dirty.mode) \(dirty.format)\n", stderr)
        failures += 1
    }

    let unknown = SessionSnapshot(mode: "sideways", format: "otf").sanitized()
    if unknown.pairMode != .simple || unknown.outputFormat != .fontlab {
        fputs("SESSION FAIL unknown mode/format: \(unknown.mode) \(unknown.format)\n", stderr)
        failures += 1
    }

    let legacyPlain = SessionSnapshot(format: "plain").sanitized()
    if legacyPlain.outputFormat != .fontlab || legacyPlain.format != "fontlab" {
        fputs("SESSION FAIL legacy plain format: \(legacyPlain.format)\n", stderr)
        failures += 1
    }

    let emptyJSON = Data("{}".utf8)
    let decoded = SessionSnapshot.decoded(from: emptyJSON)
    if decoded != .empty {
        fputs("SESSION FAIL empty json: \(decoded)\n", stderr)
        failures += 1
    }

    if let data = dirty.encoded() {
        let roundTrip = SessionSnapshot.decoded(from: data)
        if roundTrip != dirty {
            fputs("SESSION FAIL round trip\n", stderr)
            failures += 1
        }
    } else {
        fputs("SESSION FAIL encode\n", stderr)
        failures += 1
    }

    return failures
}

private enum CheckError: Error {
    case fixturesNotFound
}

private struct Fixtures: Decodable {
    let parse: [ParseCase]
    let generate: [GenerateCase]
    let plan: [PlanCase]
    let classify: [ClassifyCase]
    let generateAll: [GenerateAllCase]
}

private struct ParseCase: Decodable {
    let id: String
    let input: String
    let glyphs: [GlyphDTO]
}

private struct GlyphDTO: Decodable {
    let type: String
    let value: String
}

private struct GenerateCase: Decodable {
    let id: String
    let left: String
    let right: String
    let mode: String
    let format: String
    let expected: String
}

private struct PlanCase: Decodable {
    let id: String
    let selected: [String]
    let expected: String
}

private struct ClassifyCase: Decodable {
    let id: String
    let input: String
    let groups: [String]
    let unknown: [String]
}

private struct GenerateAllCase: Decodable {
    let id: String
    let input: String
    let format: String
    let expected: String
}

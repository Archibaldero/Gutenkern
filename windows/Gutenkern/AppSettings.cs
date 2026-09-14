using System.IO;
using System.Text.Json;

namespace Gutenkern;

internal static class AppSettings
{
    public const string SystemLanguage = "system";

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Gutenkern",
        "settings.json");

    public static string Language { get; set; } = SystemLanguage;
    public static bool HasChosenFormat { get; set; }
    public static SessionSnapshot Session { get; set; } = SessionSnapshot.Empty;

    public static void Load()
    {
        try
        {
            if (!File.Exists(FilePath))
            {
                Session = SessionSnapshot.From(
                    SessionSnapshot.DefaultGlyphs,
                    [],
                    [],
                    OutputFormat.FontLab);
                return;
            }

            var model = JsonSerializer.Deserialize<Model>(File.ReadAllText(FilePath));
            if (model is null)
            {
                return;
            }

            if (model.Language is string language && !string.IsNullOrWhiteSpace(language))
            {
                Language = language;
            }

            HasChosenFormat = true;
            Session = SessionSnapshot.Sanitize(new SessionSnapshot
            {
                Field1 = model.Field1 ?? "",
                CompletedRecipes = model.CompletedRecipes ?? [],
                CompletedBlocks = model.CompletedBlocks ?? [],
                Format = model.Format ?? "fontlab"
            });
        }
        catch
        {
            Language = SystemLanguage;
            Session = SessionSnapshot.Empty;
        }
    }

    public static void Save()
    {
        try
        {
            var directory = Path.GetDirectoryName(FilePath);
            if (!string.IsNullOrEmpty(directory))
            {
                Directory.CreateDirectory(directory);
            }

            File.WriteAllText(FilePath, JsonSerializer.Serialize(new Model
            {
                Language = Language,
                Field1 = Session.Field1,
                CompletedRecipes = Session.CompletedRecipes.ToList(),
                CompletedBlocks = Session.CompletedBlocks.ToList(),
                Format = Session.Format,
                HasChosenFormat = HasChosenFormat
            }, JsonOptions));
        }
        catch
        {
            // Preference is still applied for this session.
        }
    }

    private sealed class Model
    {
        public string Language { get; set; } = SystemLanguage;
        public string? ResultLayoutMode { get; set; }
        public string Field1 { get; set; } = "";
        public string Field2 { get; set; } = "";
        public List<string>? Groups { get; set; }
        public List<string>? CompletedRecipes { get; set; }
        public List<string>? CompletedBlocks { get; set; }
        public string? Mode { get; set; }
        public string? Format { get; set; }
        public bool HasChosenFormat { get; set; }
    }
}

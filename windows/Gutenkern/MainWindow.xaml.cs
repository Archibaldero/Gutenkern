using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;

namespace Gutenkern;

public partial class MainWindow : Window
{
    private static readonly RoutedCommand OpenSettingsCommand = new();
    private static readonly RoutedCommand CopyResultCommand = new();
    private readonly DispatcherTimer _copiedTimer;
    private readonly DispatcherTimer _persistTimer;
    private readonly HashSet<string> _completedRecipes = [];
    private bool _restoring;
    private bool _highlighting;
    private string _highlightedText = "\0";

    public MainWindow()
    {
        InitializeComponent();
        _copiedTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.5) };
        _copiedTimer.Tick += (_, _) =>
        {
            _copiedTimer.Stop();
            CopyButton.Content = L10n.Copy;
        };
        _persistTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(300) };
        _persistTimer.Tick += (_, _) =>
        {
            _persistTimer.Stop();
            PersistSession();
        };
        ApplyLocalization();
        CommandBindings.Add(new CommandBinding(
            ApplicationCommands.Save,
            SaveButton_Click,
            (_, e) => e.CanExecute = !string.IsNullOrEmpty(ResultBox?.Text)));
        CommandBindings.Add(new CommandBinding(
            CopyResultCommand,
            CopyButton_Click,
            (_, e) => e.CanExecute = !string.IsNullOrEmpty(ResultBox?.Text)));
        CommandBindings.Add(new CommandBinding(OpenSettingsCommand, (_, _) => OpenSettings()));
        InputBindings.Add(new KeyBinding(OpenSettingsCommand, Key.OemComma, ModifierKeys.Control));
        InputBindings.Add(new KeyBinding(CopyResultCommand, Key.C, ModifierKeys.Control | ModifierKeys.Shift));
        ApplyFieldChrome();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        RestoreSession();
        Refresh();
    }

    protected override void OnClosed(EventArgs e)
    {
        _persistTimer.Stop();
        PersistSession();
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        base.OnClosed(e);
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category == UserPreferenceCategory.General)
        {
            Dispatcher.BeginInvoke(ApplyFieldChrome);
        }
    }

    private void ApplyFieldChrome()
    {
        var dark = AppsUseDarkTheme();
        Resources["FieldBackgroundBrush"] = new SolidColorBrush(
            dark ? Color.FromRgb(0x19, 0x19, 0x19) : Color.FromRgb(0xFA, 0xFA, 0xFA));
        Resources["FieldBorderBrush"] = new SolidColorBrush(
            dark ? Color.FromRgb(0x33, 0x33, 0x33) : Color.FromRgb(0xF2, 0xF2, 0xF2));
    }

    private static bool AppsUseDarkTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        }
        catch
        {
            return false;
        }
    }

    private void ApplyLocalization()
    {
        WhatLabel.Content = L10n.FieldWhat;
        GroupsLabel.Content = L10n.Groups;
        PlanLabel.Content = L10n.Plan;
        FormatLabel.Content = L10n.Format;
        ResultLabel.Content = L10n.Result;
        FormatFontLab.Content = L10n.FormatFontLab;
        FormatGlyphs.Content = L10n.FormatGlyphs;
        SaveButton.Content = L10n.SaveEllipsis;
        CopyButton.Content = _copiedTimer.IsEnabled ? L10n.Copied : L10n.Copy;
        FileMenuItem.Header = L10n.File;
        SaveMenuItem.Header = L10n.Save;
        SettingsMenuItem.Header = L10n.Settings;
        HelpMenuItem.Header = L10n.Help;
        AboutMenuItem.Header = L10n.About;
    }

    internal void ReloadLocalization()
    {
        ApplyLocalization();
        Refresh();
        foreach (Window window in OwnedWindows)
        {
            if (window is AboutWindow about)
            {
                about.ApplyLocalization();
            }
        }
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e) => OpenSettings();

    private void AboutButton_Click(object sender, RoutedEventArgs e) => OpenAbout();

    private void OpenSettings()
    {
        PersistSession();
        var window = new SettingsWindow { Owner = this };
        window.ShowDialog();
    }

    private void OpenAbout()
    {
        var window = new AboutWindow { Owner = this };
        window.ShowDialog();
    }

    private void FieldsChanged(object sender, TextChangedEventArgs e)
    {
        if (_highlighting)
        {
            return;
        }

        Refresh();
        SchedulePersist();
    }

    private void OptionsChanged(object sender, RoutedEventArgs e)
    {
        Refresh();
        SchedulePersist();
    }

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(ResultBox.Text))
        {
            return;
        }

        Clipboard.SetText(ResultBox.Text);
        CopyButton.Content = L10n.Copied;
        _copiedTimer.Stop();
        _copiedTimer.Start();
    }

    private void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(ResultBox.Text))
        {
            return;
        }

        var dialog = new SaveFileDialog
        {
            Title = L10n.Save,
            Filter = $"{L10n.TextDocument} (*.txt)|*.txt|{L10n.AllFiles} (*.*)|*.*",
            DefaultExt = "txt",
            AddExtension = true,
            FileName = "kerning.txt"
        };

        if (dialog.ShowDialog() != true)
        {
            return;
        }

        try
        {
            File.WriteAllText(dialog.FileName, ResultBox.Text);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                this,
                ex.Message,
                L10n.SaveFailed,
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }

    private void Refresh()
    {
        if (Field1 is null || ResultBox is null || CopyButton is null || CountLabel is null || SaveButton is null)
        {
            return;
        }

        var input = FieldText();
        var classified = GlyphClassifier.Classify(input);
        if (input != _highlightedText)
        {
            HighlightUnknowns(input, classified);
            _highlightedText = input;
        }
        if (GroupsText is not null)
        {
            GroupsText.Text = classified.GroupsText;
        }

        var output = KerningGenerator.Generate(classified, SelectedFormat());
        ResultBox.Text = output;
        CopyButton.IsEnabled = output.Length > 0;
        SaveButton.IsEnabled = output.Length > 0;
        CountLabel.Text = L10n.PairCount(KerningGenerator.PairCount(classified));
        RefreshPlan(classified.Groups);
    }

    private void RefreshPlan(IReadOnlyList<KerningGroup> selected)
    {
        if (PlanRows is null)
        {
            return;
        }

        PlanRows.Children.Clear();
        foreach (var row in KerningPlan.Rows(selected))
        {
            var wrap = new WrapPanel { Orientation = Orientation.Horizontal };
            foreach (var recipe in row)
            {
                wrap.Children.Add(PlanToken(recipe));
            }

            PlanRows.Children.Add(wrap);
        }
    }

    private TextBlock PlanToken(string recipe)
    {
        var done = _completedRecipes.Contains(recipe);
        var run = new Run(recipe);
        var link = new Hyperlink(run)
        {
            Cursor = Cursors.Hand,
            TextDecorations = new TextDecorationCollection(),
            Focusable = false
        };
        link.Click += (_, _) =>
        {
            if (!_completedRecipes.Add(recipe))
            {
                _completedRecipes.Remove(recipe);
            }

            Refresh();
            SchedulePersist();
        };

        if (done)
        {
            link.Foreground = SystemColors.WindowTextBrush;
            run.Foreground = SystemColors.WindowTextBrush;
            run.TextDecorations = TextDecorations.Strikethrough;
        }
        else
        {
            link.Foreground = SystemColors.HotTrackBrush;
            run.Foreground = SystemColors.HotTrackBrush;
            run.TextDecorations = new TextDecorationCollection
            {
                new TextDecoration
                {
                    Location = TextDecorationLocation.Underline,
                    Pen = new Pen(SystemColors.HotTrackBrush, 1) { DashStyle = DashStyles.Dot },
                    PenOffset = 1
                }
            };
        }

        return new TextBlock(link)
        {
            FontFamily = new FontFamily("Consolas"),
            FontSize = 13,
            Margin = new Thickness(0, 0, 8, 2)
        };
    }

    private OutputFormat SelectedFormat()
    {
        if (FormatGlyphs?.IsChecked == true)
        {
            return OutputFormat.Glyphs;
        }

        return OutputFormat.FontLab;
    }

    private string FieldText()
    {
        if (Field1 is null)
        {
            return "";
        }

        var text = new TextRange(Field1.Document.ContentStart, Field1.Document.ContentEnd).Text;
        return text.TrimEnd('\r', '\n');
    }

    private void SetFieldText(string text)
    {
        if (Field1 is null)
        {
            return;
        }

        _highlighting = true;
        Field1.Document.Blocks.Clear();
        var paragraph = new Paragraph(new Run(text)) { Margin = new Thickness(0) };
        Field1.Document.Blocks.Add(paragraph);
        _highlighting = false;
        _highlightedText = "\0";
    }

    private void HighlightUnknowns(string text, ClassificationResult classified)
    {
        if (Field1 is null || _highlighting)
        {
            return;
        }

        var caret = new TextRange(Field1.Document.ContentStart, Field1.CaretPosition).Text.Length;
        var unknown = classified.Unknown
            .Select(token => (token.Start, End: token.Start + token.Length))
            .OrderBy(range => range.Start)
            .ToList();
        var paragraph = new Paragraph { Margin = new Thickness(0) };
        var index = 0;
        foreach (var (start, end) in unknown)
        {
            if (start > index)
            {
                paragraph.Inlines.Add(new Run(text[index..start]));
            }

            var run = new Run(text[start..Math.Min(end, text.Length)])
            {
                Foreground = Brushes.IndianRed
            };
            paragraph.Inlines.Add(run);
            index = Math.Min(end, text.Length);
        }

        if (index < text.Length)
        {
            paragraph.Inlines.Add(new Run(text[index..]));
        }

        if (paragraph.Inlines.Count == 0)
        {
            paragraph.Inlines.Add(new Run(text));
        }

        _highlighting = true;
        Field1.Document.Blocks.Clear();
        Field1.Document.Blocks.Add(paragraph);
        SetCaret(Field1, caret);
        _highlighting = false;
    }

    private static void SetCaret(RichTextBox box, int offset)
    {
        var pointer = box.Document.ContentStart;
        var seen = 0;
        while (pointer is not null)
        {
            if (pointer.GetPointerContext(LogicalDirection.Forward) == TextPointerContext.Text)
            {
                var run = pointer.GetTextInRun(LogicalDirection.Forward);
                if (seen + run.Length >= offset)
                {
                    box.CaretPosition = pointer.GetPositionAtOffset(offset - seen) ?? box.Document.ContentEnd;
                    return;
                }

                seen += run.Length;
            }

            pointer = pointer.GetNextContextPosition(LogicalDirection.Forward);
        }

        box.CaretPosition = box.Document.ContentEnd;
    }

    private void RestoreSession()
    {
        _restoring = true;
        var session = AppSettings.Session;
        SetFieldText(session.Field1);
        switch (session.OutputFormatValue)
        {
            case OutputFormat.Glyphs:
                FormatGlyphs.IsChecked = true;
                break;
            default:
                FormatFontLab.IsChecked = true;
                break;
        }

        _completedRecipes.Clear();
        foreach (var recipe in session.CompletedRecipes)
        {
            _completedRecipes.Add(recipe);
        }

        _restoring = false;
    }

    private void SchedulePersist()
    {
        if (_restoring)
        {
            return;
        }

        _persistTimer.Stop();
        _persistTimer.Start();
    }

    private void PersistSession()
    {
        if (Field1 is null)
        {
            return;
        }

        AppSettings.Session = SessionSnapshot.From(
            FieldText(),
            _completedRecipes,
            SelectedFormat());
        AppSettings.Save();
    }
}

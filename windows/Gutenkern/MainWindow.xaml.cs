using System.Diagnostics;
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
    private readonly DispatcherTimer _persistTimer;
    private readonly DispatcherTimer _toastTimer;
    private readonly HashSet<string> _completedRecipes = [];
    private readonly HashSet<string> _completedBlocks = [];
    private readonly MarkHistory _markHistory = new();
    private bool _restoring = true;
    private bool _highlighting;
    private bool _lastActionWasMark;
    private bool _ignoringCategorySync;
    private KerningGroup? _selectedCategory;
    private string _highlightedText = "\0";
    private string _output = "";
    private string _resultText = "\0";
    private Dictionary<string, HashSet<string>> _previousGroupKeys = [];
    private HashSet<string> _warningGroupIds = [];
    private HashSet<string> _newUnkernedKeys = [];
    private List<RecipeSection> _recipeSections = [];
    private ResultLayout _layout = ResultLayout.Empty;
    private OutputFormat _format = OutputFormat.FontLab;

    public MainWindow()
    {
        InitializeComponent();
        _toastTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _toastTimer.Tick += (_, _) =>
        {
            _toastTimer.Stop();
            if (CopiedToast is not null)
            {
                CopiedToast.Visibility = Visibility.Collapsed;
            }
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
            (_, e) => e.CanExecute = !string.IsNullOrEmpty(_output)));
        CommandBindings.Add(new CommandBinding(OpenSettingsCommand, (_, _) => OpenSettings()));
        InputBindings.Add(new KeyBinding(OpenSettingsCommand, Key.OemComma, ModifierKeys.Control));
        ApplyFieldChrome();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        RestoreSession();
        Refresh();
        Loaded += (_, _) =>
        {
            PromptFormatIfNeeded();
            _restoring = false;
        };
        ResultBox.AddHandler(ScrollViewer.ScrollChangedEvent, new ScrollChangedEventHandler(Result_ScrollChanged), true);
        DataObject.AddCopyingHandler(ResultBox, Result_Copying);
    }

    public OutputFormat CurrentFormat() => _format;

    public bool HasProgress() => _completedBlocks.Count > 0 || _completedRecipes.Count > 0;

    public void SetFormat(OutputFormat format)
    {
        if (_format == format)
        {
            return;
        }

        _format = format;
        SyncFormatMenus();
        Refresh();
        SchedulePersist();
    }

    public void ResetProgress()
    {
        ApplyState(new KerningMarkState([]));
    }

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        base.OnPreviewKeyDown(e);
        if (HandleMarkHistoryKey(e))
        {
            e.Handled = true;
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        _persistTimer.Stop();
        _toastTimer.Stop();
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
            dark ? Color.FromRgb(0x1A, 0x1A, 0x1A) : Color.FromRgb(0xFC, 0xFC, 0xFC));
        Resources["FieldBorderBrush"] = new SolidColorBrush(
            dark ? Color.FromRgb(0x26, 0x26, 0x26) : Color.FromRgb(0xF2, 0xF2, 0xF2));
        Background = new SolidColorBrush(dark ? Color.FromRgb(0x1A, 0x1A, 0x1A) : Colors.White);
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
        WhatLabel.Text = L10n.FieldWhat;
        ResultLabel.Text = L10n.Result;
        ResultPlaceholder.Text = L10n.ResultPlaceholder;
        CopyAllButton.Content = L10n.CopyAll;
        SaveButton.Content = L10n.SaveEllipsis;
        SaveAndOpenButton.Content = L10n.SaveAndOpenEllipsis;
        UndoMenuItem.Header = L10n.Undo;
        RedoMenuItem.Header = L10n.Redo;
        FileMenuItem.Header = L10n.File;
        SaveMenuItem.Header = L10n.Save;
        SettingsMenuItem.Header = L10n.Settings;
        SettingsWindowMenuItem.Header = L10n.Settings;
        FormatFontLabMenu.Header = L10n.FormatFontLab;
        FormatGlyphsMenu.Header = L10n.FormatGlyphs;
        ResetProgressMenu.Header = L10n.ResetProgress;
        HelpMenuItem.Header = L10n.Help;
        AboutMenuItem.Header = L10n.About;
        if (CopiedToastText is not null)
        {
            CopiedToastText.Text = L10n.GroupCopied;
        }
        RebuildCategoryNav();
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

        _lastActionWasMark = false;
        Refresh();
        SchedulePersist();
    }

    private void FormatMenu_Click(object sender, RoutedEventArgs e)
    {
        SetFormat(sender == FormatGlyphsMenu ? OutputFormat.Glyphs : OutputFormat.FontLab);
    }

    private void CopyAll_Click(object sender, RoutedEventArgs e) => CopyText(_output);

    private void SaveButton_Click(object sender, RoutedEventArgs e) => SaveOutput(open: false);

    private void SaveAndOpen_Click(object sender, RoutedEventArgs e) => SaveOutput(open: true);

    private void ResetProgress_Click(object sender, RoutedEventArgs e) => ResetProgress();

    private void UndoMarks_Click(object sender, RoutedEventArgs e) => UndoMarks();

    private void RedoMarks_Click(object sender, RoutedEventArgs e) => RedoMarks();

    private void SaveOutput(bool open)
    {
        SaveText(_output, open);
    }

    private void SaveText(string text, bool open)
    {
        if (string.IsNullOrEmpty(text))
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
            File.WriteAllText(dialog.FileName, TokenGlue.Clean(text));
            if (open)
            {
                Process.Start(new ProcessStartInfo(dialog.FileName) { UseShellExecute = true });
            }
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
        if (Field1 is null || SaveButton is null || ResultBox is null)
        {
            return;
        }

        var text = FieldText();
        var classified = GlyphClassifier.Classify(text);
        HighlightUnknowns(text, classified);
        _recipeSections = KerningGenerator.GenerateRecipeSections(classified, _format);
        _layout = ResultLayout.Build(_recipeSections, ResultLayoutMode.Row);
        _output = _layout.Text;
        SyncCompletion();
        RefreshNewUnkerned();
        UpdateResultDocument();
        RebuildCategoryNav();
        UpdateFooter();
        SyncFormatMenus();
        ResultPlaceholder.Visibility = string.IsNullOrEmpty(_output) ? Visibility.Visible : Visibility.Collapsed;
        CopyAllButton.IsEnabled = !string.IsNullOrEmpty(_output);
        SaveButton.IsEnabled = !string.IsNullOrEmpty(_output);
        SaveAndOpenButton.IsEnabled = !string.IsNullOrEmpty(_output);
        ResetProgressMenu.IsEnabled = HasProgress();
    }

    private void UpdateFooter()
    {
        var total = _layout.Tokens.Count;
        var done = _completedBlocks.Intersect(_layout.Tokens.Select(token => token.Key)).Count();
        if (TotalPairCount is not null)
        {
            TotalPairCount.Text = L10n.PairProgress(done, total);
            TotalPairCount.Visibility = total == 0 ? Visibility.Collapsed : Visibility.Visible;
        }
    }

    private void RebuildCategoryNav()
    {
        if (CategoryNav is null)
        {
            return;
        }

        CategoryNav.Children.Clear();
        var progressByCategory = _layout.ProgressByCategory(_completedBlocks);
        foreach (var category in _layout.Categories)
        {
            var group = category.Group;
            progressByCategory.TryGetValue(group, out var progress);
            var current = _selectedCategory == group;
            var item = new TextBlock
            {
                Text = L10n.GroupSidebarLabel(group, progress.Done, progress.Total),
                Tag = group,
                Margin = new Thickness(0, 0, 0, 10),
                TextWrapping = TextWrapping.NoWrap
            };
            StyleCategoryLink(item, current);
            item.MouseLeftButtonUp += (_, _) => ScrollToCategory(group);
            CategoryNav.Children.Add(item);
        }
    }

    private void StyleCategoryLink(TextBlock item, bool current)
    {
        var linkBrush = new SolidColorBrush(Color.FromRgb(0, 170, 255));
        item.Foreground = current ? SystemColors.ControlTextBrush : linkBrush;
        item.Cursor = Cursors.Hand;
        item.TextDecorations = null;
    }

    private void ScrollToCategory(KerningGroup group)
    {
        if (!_layout.CategoryStarts.TryGetValue(group, out var start))
        {
            return;
        }

        _ignoringCategorySync = true;
        _selectedCategory = group;
        ScrollResultTo(start);
        ApplyCategoryNavStyles();
        Dispatcher.BeginInvoke(() => _ignoringCategorySync = false, DispatcherPriority.Background);
    }

    private void ApplyCategoryNavStyles()
    {
        if (CategoryNav is null)
        {
            return;
        }

        foreach (var child in CategoryNav.Children)
        {
            if (child is not TextBlock item || item.Tag is not KerningGroup group)
            {
                continue;
            }

            StyleCategoryLink(item, _selectedCategory == group);
        }
    }

    private void Result_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        if (_ignoringCategorySync || ResultBox is null || _layout.IsEmpty)
        {
            return;
        }

        var pointer = ResultBox.GetPositionFromPoint(new Point(8, 8), true);
        if (pointer is null)
        {
            return;
        }

        var index = OffsetFromStart(pointer);
        var category = _layout.CategoryAtUtf16(index);
        if (category is null || category == _selectedCategory)
        {
            return;
        }

        _ignoringCategorySync = true;
        _selectedCategory = category;
        ApplyCategoryNavStyles();
        _ignoringCategorySync = false;
    }

    private void UpdateResultDocument()
    {
        if (ResultBox is null)
        {
            return;
        }

        var state = CurrentMarkState();
        var viewText = ResultViewText();
        if (_resultText == viewText)
        {
            ApplyResultMarks(state);
            return;
        }

        var paragraph = new Paragraph { Background = Brushes.Transparent };
        ResultBox.Document.Background = Brushes.Transparent;
        var cursor = 0;
        foreach (var token in _layout.Tokens)
        {
            var viewStart = TokenGlue.ViewIndex(viewText, token.Utf16Start);
            if (viewStart > cursor)
            {
                AddViewInlines(paragraph, viewText[cursor..viewStart]);
            }

            var viewEnd = TokenGlue.ViewIndex(viewText, token.Utf16End);
            var run = new Run(viewText[viewStart..viewEnd]) { Tag = token };
            ApplyTokenStyle(run, token, state);
            paragraph.Inlines.Add(run);
            cursor = viewEnd;
        }

        if (cursor < viewText.Length)
        {
            AddViewInlines(paragraph, viewText[cursor..]);
        }

        if (paragraph.Inlines.Count == 0)
        {
            paragraph.Inlines.Add(new Run(""));
        }

        ResultBox.Document.Blocks.Clear();
        ResultBox.Document.Blocks.Add(paragraph);
        _resultText = viewText;
    }

    private void ApplyResultMarks(KerningMarkState state)
    {
        if (ResultBox.Document.Blocks.FirstBlock is not Paragraph paragraph)
        {
            return;
        }

        foreach (var inline in paragraph.Inlines)
        {
            if (inline is Run run && run.Tag is ResultToken token)
            {
                ApplyTokenStyle(run, token, state);
            }
        }
    }

    private void ApplyTokenStyle(Run run, ResultToken token, KerningMarkState state)
    {
        if (state.PairMark(token.Key) == PairMark.Done)
        {
            run.TextDecorations = TextDecorations.Strikethrough;
            run.FontWeight = FontWeights.Normal;
            run.Foreground = SystemColors.WindowTextBrush;
            return;
        }

        run.TextDecorations = null;
        if (_newUnkernedKeys.Contains(token.Key))
        {
            run.FontWeight = FontWeights.Bold;
            run.Foreground = NewPairBrush();
        }
        else
        {
            run.FontWeight = FontWeights.Normal;
            run.Foreground = SystemColors.WindowTextBrush;
        }
    }

    private static Brush NewPairBrush() =>
        new SolidColorBrush(Color.FromRgb(0xFF, 0x40, 0x00));

    private void RefreshNewUnkerned()
    {
        var current = _layout.KeysByGroup();
        var updated = NewUnkernedNotice.Update(
            _previousGroupKeys,
            current,
            _completedBlocks,
            _warningGroupIds,
            _newUnkernedKeys);
        _warningGroupIds = updated.WarningGroupIds;
        _newUnkernedKeys = updated.NewKeys;
        _previousGroupKeys = current;
    }

    private void Result_ContextMenuOpening(object sender, ContextMenuEventArgs e)
    {
        var selection = ResultBox.Selection;
        var selectedText = TokenGlue.Clean(selection.Text.Replace("\r", ""));
        var start = OffsetFromStart(selection.Start);
        var tokens = selectedText.Length > 0
            ? _layout.TokensInUtf16(start, selectedText.Length)
            : _layout.TokensInUtf16(start, 0);
        var keys = tokens.Select(token => token.Key).ToList();
        var copyText = selectedText.Length > 0 ? selectedText : tokens.FirstOrDefault()?.Display ?? "";
        var saveText = selectedText.Length > 0 ? selectedText : _layout.Text;
        var state = CurrentMarkState();

        var menu = new ContextMenu();
        menu.Items.Add(MenuItem(L10n.Copy, () => CopyText(copyText), copyText.Length > 0));
        menu.Items.Add(MenuItem(
            L10n.StrikeThrough,
            () => ApplyState(ResultSelectionMarks.Strike(keys, state)),
            ResultSelectionMarks.CanStrike(keys, state)));
        menu.Items.Add(MenuItem(
            L10n.ClearStrike,
            () => ApplyState(ResultSelectionMarks.Unstrike(keys, state)),
            ResultSelectionMarks.CanUnstrike(keys, state)));
        menu.Items.Add(MenuItem(L10n.SaveAsFile, () => SaveText(saveText, false), saveText.Length > 0));
        ResultBox.ContextMenu = menu;
    }

    private void Result_Copying(object sender, DataObjectCopyingEventArgs e)
    {
        var clean = TokenGlue.Clean(ResultBox.Selection.Text.Replace("\r", ""));
        if (e.IsDragDrop)
        {
            e.DataObject.SetData(DataFormats.UnicodeText, clean);
            return;
        }

        e.CancelCommand();
        if (!string.IsNullOrEmpty(clean))
        {
            Clipboard.SetText(clean);
        }
    }

    private int OffsetFromStart(TextPointer pointer) =>
        TokenGlue.LayoutIndex(
            ResultViewText(),
            new TextRange(ResultBox.Document.ContentStart, pointer).Text.Replace("\r", "").Length);

    private void ScrollResultTo(int utf16Start)
    {
        if (ResultBox.Document.Blocks.FirstBlock is not Paragraph paragraph)
        {
            return;
        }

        var viewStart = TokenGlue.ViewIndex(ResultViewText(), utf16Start);
        var seen = 0;
        foreach (var inline in paragraph.Inlines)
        {
            if (inline is LineBreak)
            {
                seen += 1;
                if (seen >= viewStart)
                {
                    inline.BringIntoView();
                    return;
                }

                continue;
            }

            if (inline is not Run run)
            {
                continue;
            }

            var length = run.Text.Length;
            if (seen + length >= viewStart)
            {
                run.BringIntoView();
                return;
            }

            seen += length;
        }
    }

    private static void AddViewInlines(Paragraph paragraph, string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return;
        }

        var start = 0;
        for (var index = 0; index < text.Length; index++)
        {
            if (text[index] != '\n')
            {
                continue;
            }

            if (index > start)
            {
                paragraph.Inlines.Add(new Run(text[start..index]));
            }

            paragraph.Inlines.Add(new LineBreak());
            start = index + 1;
        }

        if (start < text.Length)
        {
            paragraph.Inlines.Add(new Run(text[start..]));
        }
    }

    private string ResultViewText() => _layout.ViewText;

    private static MenuItem MenuItem(string header, Action action, bool enabled)
    {
        var item = new MenuItem { Header = header, IsEnabled = enabled };
        item.Click += (_, _) => action();
        return item;
    }

    private void CopyText(string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return;
        }

        Clipboard.SetText(TokenGlue.Clean(text));
        ShowCopiedToast(L10n.GroupCopied);
    }

    private void ApplyState(KerningMarkState state, bool record = true)
    {
        if (record)
        {
            _markHistory.Record(CurrentMarkState(), state);
            _lastActionWasMark = true;
        }

        var completion = CurrentCompletion();
        completion.ApplyDone(state.Done, _recipeSections);
        ApplyCompletion(completion);
        RefreshNewUnkerned();
        RebuildCategoryNav();
        UpdateFooter();
        ApplyResultMarks(CurrentMarkState());
        SchedulePersist();
    }

    private void UndoMarks()
    {
        var previous = _markHistory.Undo(CurrentMarkState());
        if (previous is null)
        {
            return;
        }

        ApplyState(previous, record: false);
    }

    private void RedoMarks()
    {
        var next = _markHistory.Redo(CurrentMarkState());
        if (next is null)
        {
            return;
        }

        ApplyState(next, record: false);
    }

    private bool HandleMarkHistoryKey(KeyEventArgs e)
    {
        if (!Keyboard.Modifiers.HasFlag(ModifierKeys.Control) || !IsZKey(e))
        {
            return false;
        }

        if (!_lastActionWasMark)
        {
            return false;
        }

        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift))
        {
            if (!_markHistory.CanRedo)
            {
                return false;
            }

            RedoMarks();
            return true;
        }

        if (!_markHistory.CanUndo)
        {
            return false;
        }

        UndoMarks();
        return true;
    }

    private static bool IsZKey(KeyEventArgs e) => e.Key == Key.Z || e.SystemKey == Key.Z;

    private KerningMarkState CurrentMarkState() => new(_completedBlocks);

    private void ShowCopiedToast(string text)
    {
        if (CopiedToast is null || CopiedToastText is null)
        {
            return;
        }

        CopiedToastText.Text = text;
        CopiedToast.Visibility = Visibility.Visible;
        _toastTimer.Stop();
        _toastTimer.Start();
    }

    private void SyncFormatMenus()
    {
        FormatFontLabMenu.IsChecked = _format == OutputFormat.FontLab;
        FormatGlyphsMenu.IsChecked = _format == OutputFormat.Glyphs;
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
        if (Field1 is null || _highlighting || text == _highlightedText)
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
        _highlightedText = text;
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

    private KerningCompletion CurrentCompletion() =>
        new(_completedRecipes, _completedBlocks);

    private void ApplyCompletion(KerningCompletion completion)
    {
        _completedRecipes.Clear();
        foreach (var recipe in completion.Recipes)
        {
            _completedRecipes.Add(recipe);
        }

        _completedBlocks.Clear();
        foreach (var block in completion.Blocks)
        {
            _completedBlocks.Add(block);
        }
    }

    private void SyncCompletion()
    {
        var completion = CurrentCompletion();
        completion.Sync(_recipeSections);
        if (completion.Recipes.SetEquals(_completedRecipes) &&
            completion.Blocks.SetEquals(_completedBlocks))
        {
            return;
        }

        ApplyCompletion(completion);
        if (!_restoring)
        {
            SchedulePersist();
        }
    }

    private void RestoreSession()
    {
        _restoring = true;
        var session = AppSettings.Session;
        SetFieldText(session.Field1);
        _format = session.OutputFormatValue;
        _completedRecipes.Clear();
        foreach (var recipe in session.CompletedRecipes)
        {
            _completedRecipes.Add(recipe);
        }

        _completedBlocks.Clear();
        foreach (var block in session.CompletedBlocks)
        {
            _completedBlocks.Add(block);
        }

        SyncFormatMenus();
    }

    private void PromptFormatIfNeeded()
    {
        if (AppSettings.HasChosenFormat)
        {
            return;
        }

        var window = new FormatChoiceWindow { Owner = this };
        window.ShowDialog();
        _format = window.Selected;
        AppSettings.HasChosenFormat = true;
        SyncFormatMenus();
        Refresh();
        PersistSession();
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
            _completedBlocks,
            _format);
        AppSettings.Save();
    }
}

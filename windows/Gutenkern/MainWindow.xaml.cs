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
        WithLabel.Content = L10n.FieldWith;
        GroupsLabel.Content = L10n.Groups;
        PlanLabel.Content = L10n.Plan;
        TypeLabel.Content = L10n.Type;
        FormatLabel.Content = L10n.Format;
        ResultLabel.Content = L10n.Result;
        ModeSimple.Content = L10n.TypeSimple;
        ModeMirror.Content = L10n.TypeMirror;
        FormatFontLab.Content = L10n.FormatFontLab;
        FormatGlyphs.Content = L10n.FormatGlyphs;
        GroupCapitals.Content = L10n.GroupLabel(KerningGroup.Capitals);
        GroupSmallCaps.Content = L10n.GroupLabel(KerningGroup.SmallCaps);
        GroupLowercase.Content = L10n.GroupLabel(KerningGroup.Lowercase);
        GroupPunctuation.Content = L10n.GroupLabel(KerningGroup.Punctuation);
        GroupNonAlphabetic.Content = L10n.GroupLabel(KerningGroup.NonAlphabetic);
        GroupLiningFigures.Content = L10n.GroupLabel(KerningGroup.LiningFigures);
        GroupOldstyleFigures.Content = L10n.GroupLabel(KerningGroup.OldstyleFigures);
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
        Refresh();
        SchedulePersist();
    }

    private void OptionsChanged(object sender, RoutedEventArgs e)
    {
        Refresh();
        SchedulePersist();
    }

    private void PlanChanged(object sender, RoutedEventArgs e)
    {
        RefreshPlan();
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
        if (Field1 is null || Field2 is null || ResultBox is null || CopyButton is null || CountLabel is null || SaveButton is null)
        {
            return;
        }

        var mode = ModeMirror?.IsChecked == true ? PairMode.Mirror : PairMode.Simple;
        var output = KerningGenerator.Generate(Field1.Text, Field2.Text, mode, SelectedFormat());
        ResultBox.Text = output;
        CopyButton.IsEnabled = output.Length > 0;
        SaveButton.IsEnabled = output.Length > 0;
        CountLabel.Text = L10n.PairCount(KerningGenerator.PairCount(Field1.Text, Field2.Text));
        RefreshPlan();
    }

    private void RefreshPlan()
    {
        if (PlanRows is null)
        {
            return;
        }

        var selected = SelectedGroups();

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

            RefreshPlan();
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

    private HashSet<KerningGroup> SelectedGroups()
    {
        var selected = new HashSet<KerningGroup>();
        if (GroupCapitals?.IsChecked == true) selected.Add(KerningGroup.Capitals);
        if (GroupSmallCaps?.IsChecked == true) selected.Add(KerningGroup.SmallCaps);
        if (GroupLowercase?.IsChecked == true) selected.Add(KerningGroup.Lowercase);
        if (GroupPunctuation?.IsChecked == true) selected.Add(KerningGroup.Punctuation);
        if (GroupNonAlphabetic?.IsChecked == true) selected.Add(KerningGroup.NonAlphabetic);
        if (GroupLiningFigures?.IsChecked == true) selected.Add(KerningGroup.LiningFigures);
        if (GroupOldstyleFigures?.IsChecked == true) selected.Add(KerningGroup.OldstyleFigures);
        return selected;
    }

    private OutputFormat SelectedFormat()
    {
        if (FormatGlyphs?.IsChecked == true)
        {
            return OutputFormat.Glyphs;
        }

        return OutputFormat.FontLab;
    }

    private void RestoreSession()
    {
        _restoring = true;
        var session = AppSettings.Session;
        Field1.Text = session.Field1;
        Field2.Text = session.Field2;

        GroupCapitals.IsChecked = session.SelectedGroups.Contains(KerningGroup.Capitals);
        GroupSmallCaps.IsChecked = session.SelectedGroups.Contains(KerningGroup.SmallCaps);
        GroupLowercase.IsChecked = session.SelectedGroups.Contains(KerningGroup.Lowercase);
        GroupPunctuation.IsChecked = session.SelectedGroups.Contains(KerningGroup.Punctuation);
        GroupNonAlphabetic.IsChecked = session.SelectedGroups.Contains(KerningGroup.NonAlphabetic);
        GroupLiningFigures.IsChecked = session.SelectedGroups.Contains(KerningGroup.LiningFigures);
        GroupOldstyleFigures.IsChecked = session.SelectedGroups.Contains(KerningGroup.OldstyleFigures);

        ModeMirror.IsChecked = session.PairModeValue == PairMode.Mirror;
        ModeSimple.IsChecked = session.PairModeValue != PairMode.Mirror;
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
        if (Field1 is null || Field2 is null)
        {
            return;
        }

        AppSettings.Session = SessionSnapshot.From(
            Field1.Text,
            Field2.Text,
            SelectedGroups(),
            _completedRecipes,
            ModeMirror?.IsChecked == true ? PairMode.Mirror : PairMode.Simple,
            SelectedFormat());
        AppSettings.Save();
    }
}

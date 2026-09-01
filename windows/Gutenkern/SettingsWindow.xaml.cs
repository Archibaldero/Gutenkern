using System.Windows;
using System.Windows.Controls;

namespace Gutenkern;

public partial class SettingsWindow : Window
{
    private bool _updating;

    public SettingsWindow()
    {
        InitializeComponent();
        PopulateLanguages();
        ApplyLocalization();
    }

    private void ApplyLocalization()
    {
        Title = L10n.Settings;
        LanguageLabel.Content = L10n.LanguageLabel;
        if (LanguageCombo.Items.Count > 0 && LanguageCombo.Items[0] is ComboBoxItem systemItem)
        {
            systemItem.Content = L10n.LanguageSystem;
        }
    }

    private void PopulateLanguages()
    {
        _updating = true;
        LanguageCombo.Items.Clear();
        LanguageCombo.Items.Add(new ComboBoxItem
        {
            Content = L10n.LanguageSystem,
            Tag = AppSettings.SystemLanguage
        });
        foreach (var language in L10n.Languages)
        {
            LanguageCombo.Items.Add(new ComboBoxItem
            {
                Content = language.NativeName,
                Tag = language.Code
            });
        }

        foreach (ComboBoxItem item in LanguageCombo.Items)
        {
            if (Equals(item.Tag, AppSettings.Language))
            {
                LanguageCombo.SelectedItem = item;
                break;
            }
        }

        if (LanguageCombo.SelectedItem is null && LanguageCombo.Items.Count > 0)
        {
            LanguageCombo.SelectedIndex = 0;
        }

        _updating = false;
    }

    private void LanguageCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_updating || LanguageCombo.SelectedItem is not ComboBoxItem item || item.Tag is not string code)
        {
            return;
        }

        AppSettings.Language = code;
        AppSettings.Save();
        L10n.ApplyPreference(code);
        ApplyLocalization();
        if (Owner is MainWindow mainWindow)
        {
            mainWindow.ReloadLocalization();
        }
    }
}

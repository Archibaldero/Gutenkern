using System.Windows;

namespace Gutenkern;

public partial class FormatChoiceWindow : Window
{
    public OutputFormat Selected { get; private set; } = OutputFormat.FontLab;

    public FormatChoiceWindow()
    {
        InitializeComponent();
        Title = L10n.ChooseFormat;
        PromptLabel.Text = L10n.ChooseFormat;
        FontLabButton.Content = L10n.FormatFontLab;
        GlyphsButton.Content = L10n.FormatGlyphs;
    }

    private void FontLab_Click(object sender, RoutedEventArgs e)
    {
        Selected = OutputFormat.FontLab;
        DialogResult = true;
    }

    private void Glyphs_Click(object sender, RoutedEventArgs e)
    {
        Selected = OutputFormat.Glyphs;
        DialogResult = true;
    }
}

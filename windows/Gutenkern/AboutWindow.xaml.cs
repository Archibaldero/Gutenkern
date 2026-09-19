using System.Diagnostics;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Navigation;

namespace Gutenkern;

public partial class AboutWindow : Window
{
    public AboutWindow()
    {
        InitializeComponent();
        ApplyLocalization();
    }

    internal void ApplyLocalization()
    {
        Title = L10n.About;
        BodyText.Text = L10n.AboutBody;
        FillLinkedText(VersionText, L10n.AboutVersionParts(AppVersion()));
        FillLinkedText(CreditBlock, L10n.AboutCreditsParts());
    }

    private void FillLinkedText(TextBlock block, List<CreditPart> parts)
    {
        block.Inlines.Clear();
        foreach (var part in parts)
        {
            if (part.Link is Uri uri)
            {
                block.Inlines.Add(CreateLink(part.Text, uri));
            }
            else
            {
                block.Inlines.Add(new Run(part.Text));
            }
        }
    }

    private Hyperlink CreateLink(string label, Uri uri)
    {
        var link = new Hyperlink(new Run(label)) { NavigateUri = uri };
        link.RequestNavigate += OnLinkRequestNavigate;
        return link;
    }

    private static void OnLinkRequestNavigate(object sender, RequestNavigateEventArgs e)
    {
        Process.Start(new ProcessStartInfo(e.Uri.AbsoluteUri) { UseShellExecute = true });
        e.Handled = true;
    }

    private static string AppVersion()
    {
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        if (version is null)
        {
            return "1.0";
        }

        return $"{version.Major}.{version.Minor}";
    }
}

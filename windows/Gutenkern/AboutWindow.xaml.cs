using System.Diagnostics;
using System.Reflection;
using System.Windows;
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
        VersionText.Text = L10n.AboutVersion(AppVersion());
        BodyText.Text = L10n.AboutBody;

        ContactBlock.Inlines.Clear();
        ContactBlock.Inlines.Add(new Run(L10n.AboutContact + " "));
        ContactBlock.Inlines.Add(CreateLink(L10n.AuthorEmail, new Uri("mailto:" + L10n.AuthorEmail)));

        CreditBlock.Inlines.Clear();
        CreditBlock.Inlines.Add(new Run(L10n.AboutCopyright));
        CreditBlock.Inlines.Add(new LineBreak());
        CreditBlock.Inlines.Add(CreateLink(L10n.AuthorWebsite, new Uri("https://" + L10n.AuthorWebsite)));
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

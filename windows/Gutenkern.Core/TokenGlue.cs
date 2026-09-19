using System.Globalization;
using System.Text;

namespace Gutenkern;

public static class TokenGlue
{
    public const char Joiner = '\u2060';
    public const char ViewSlash = '\u29F8';
    public const char AsciiSlash = '/';

    public static string Apply(string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return text;
        }

        var enumerator = StringInfo.GetTextElementEnumerator(text);
        var builder = new StringBuilder();
        var first = true;
        while (enumerator.MoveNext())
        {
            if (!first)
            {
                builder.Append(Joiner);
            }

            var element = enumerator.GetTextElement();
            builder.Append(element == "/" ? ViewSlash.ToString() : element);
            first = false;
        }

        return builder.ToString();
    }

    public static string Strip(string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return text;
        }

        return text.Replace(Joiner.ToString(), "").Replace(ViewSlash, AsciiSlash);
    }

    public static string Clean(string text) => Strip(text);

    public static string ViewText(
        string layoutText,
        IReadOnlyList<ResultToken> tokens,
        Func<ResultToken, bool>? shouldGlue = null)
    {
        shouldGlue ??= static _ => true;
        var builder = new StringBuilder();
        var cursor = 0;
        foreach (var token in tokens)
        {
            if (token.Utf16Start > cursor)
            {
                builder.Append(layoutText[cursor..token.Utf16Start]);
            }

            builder.Append(shouldGlue(token) ? Apply(token.Display) : token.Display);
            cursor = token.Utf16End;
        }

        if (cursor < layoutText.Length)
        {
            builder.Append(layoutText[cursor..]);
        }

        return builder.ToString();
    }

    public static int LayoutIndex(string view, int viewIndex)
    {
        var end = Math.Clamp(viewIndex, 0, view.Length);
        var layout = 0;
        for (var index = 0; index < end; index++)
        {
            if (view[index] != Joiner)
            {
                layout++;
            }
        }

        return layout;
    }

    public static int ViewIndex(string view, int layoutIndex)
    {
        var layout = 0;
        for (var index = 0; index < view.Length; index++)
        {
            if (view[index] == Joiner)
            {
                continue;
            }

            if (layout >= layoutIndex)
            {
                return index;
            }

            layout++;
        }

        return view.Length;
    }
}

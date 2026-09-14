namespace Gutenkern;

public sealed class CopyBurst
{
    public static readonly TimeSpan Window = TimeSpan.FromSeconds(1);

    private readonly List<string> _keys = [];
    private DateTime? _lastTime;

    public IReadOnlyList<string> Keys => _keys;

    public void Reset()
    {
        _keys.Clear();
        _lastTime = null;
    }

    public IReadOnlyList<string> Add(string key, DateTime time)
    {
        if (_lastTime is { } last && time - last >= Window)
        {
            _keys.Clear();
        }

        if (!_keys.Contains(key))
        {
            _keys.Add(key);
        }

        _lastTime = time;
        return _keys.ToArray();
    }
}

using System.Text.RegularExpressions;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Tests.Localization;

// The Texts catalog is the only place with user text. This scan keeps it that way: a Spanish word in a
// string literal of src/ (outside Localization/) fails the build of the tests.
public partial class NoSpanishLiteralsTests
{
    private static readonly string[] SpanishWords =
    [
        "Hoy", "Vencida", "Hecha", "Hechas", "Semana", "Abrir", "Salir", "Mayús", "Ayer", "Desde",
        "Prioridad", "Prioridades", "Posponer", "Probar", "Pendiente", "Cancelar", "Añadir", "Deshacer",
        "Regresar", "Notas", "Ajustes", "Historial", "Creada", "Queda", "Quedan", "Nueva", "Quitar",
    ];

    private static readonly Lazy<IReadOnlyList<string>> CatalogOnlySpanish = new(SpanishOnlyCatalogStrings);

    [GeneratedRegex(@"\$?@?""((?:[^""\\]|\\.)*)""")]
    private static partial Regex Literal();

    [GeneratedRegex(@"<!--.*?-->", RegexOptions.Singleline)]
    private static partial Regex XmlComment();

    [GeneratedRegex(@">\s*([^<>{}\s][^<>{}]*?)\s*<")]
    private static partial Regex XamlText();

    [Fact]
    public void No_source_file_outside_Localization_holds_a_Spanish_literal()
    {
        var src = Path.Combine(RepositoryApp(), "src");
        var files = Directory
            .EnumerateFiles(src, "*.*", SearchOption.AllDirectories)
            .Where(path => path.EndsWith(".cs", StringComparison.Ordinal) || path.EndsWith(".xaml", StringComparison.Ordinal))
            .Where(path => !IsExcluded(Path.GetRelativePath(src, path)))
            .ToList();
        Assert.Contains(files, path => path.EndsWith("AppStore.cs", StringComparison.Ordinal));

        var violations = files
            .SelectMany(path => Violations(path, File.ReadAllText(path)).Select(line => $"{Path.GetRelativePath(src, path)}: {line}"))
            .ToList();

        Assert.True(violations.Count == 0, "Spanish text outside the catalog:\n" + string.Join('\n', violations));
    }

    [Theory]
    [InlineData("var chip = \"Hoy\";", true)]
    [InlineData("var chip = $\"Vencida {minutes}\";", true)]
    [InlineData("menu.Add(\"Abrir\");", true)]
    [InlineData("parts.Add(\"Mayús\");", true)]
    [InlineData("var title = \"Eliminar prioridad\";", true)]
    [InlineData("var title = \"Qué pasó\";", true)]
    [InlineData("// Hoy is the first scope", false)]
    [InlineData("var x = 1; // \"Hoy\"", false)]
    [InlineData("var id = \"Hoyo\";", false)]
    [InlineData("var tab = \"Tab\";", false)]
    [InlineData("var key = \"alert_id\";", false)]
    public void The_scan_flags_Spanish_literals_in_code(string line, bool flagged)
    {
        Assert.Equal(flagged, Violations("File.cs", line).Any());
    }

    [Theory]
    [InlineData("<Button Content=\"Abrir\" />", true)]
    [InlineData("<TextBlock>Semana</TextBlock>", true)]
    [InlineData("<TextBlock Text=\"{Binding Title}\" />", false)]
    [InlineData("<!-- Hoy --><Grid />", false)]
    [InlineData("<Border AutomationProperties.AutomationId=\"ScopeToday\" />", false)]
    public void The_scan_flags_Spanish_literals_in_xaml(string markup, bool flagged)
    {
        Assert.Equal(flagged, Violations("View.xaml", markup).Any());
    }

    [Fact]
    public void The_catalog_words_that_only_Spanish_uses_are_watched_too()
    {
        Assert.Contains("Eliminar prioridad", CatalogOnlySpanish.Value);
        Assert.Contains("Regresar", CatalogOnlySpanish.Value);
        Assert.DoesNotContain("Tab", CatalogOnlySpanish.Value);
        Assert.DoesNotContain("Win", CatalogOnlySpanish.Value);
    }

    // Gallery is a developer-only style sheet with sample rows; users never see it.
    private static bool IsExcluded(string relativePath)
    {
        var parts = relativePath.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return parts.Any(part => part is "Localization" or "Gallery" or "obj" or "bin");
    }

    private static IEnumerable<string> Violations(string fileName, string text)
    {
        var isXaml = fileName.EndsWith(".xaml", StringComparison.Ordinal);
        if (isXaml)
        {
            text = XmlComment().Replace(text, string.Empty);
        }

        var lineNumber = 0;
        foreach (var rawLine in text.Split('\n'))
        {
            lineNumber++;
            var line = isXaml ? rawLine : WithoutComment(rawLine);
            var literals = Literal().Matches(line).Select(match => match.Groups[1].Value);
            if (isXaml)
            {
                literals = literals.Concat(XamlText().Matches(line).Select(match => match.Groups[1].Value));
            }

            foreach (var literal in literals.Where(IsSpanish))
            {
                yield return $"line {lineNumber}: \"{literal}\"";
            }
        }
    }

    private static bool IsSpanish(string literal)
    {
        var value = literal.Trim();
        return value.Length > 0
            && (value.Any(c => "áéíóúñÁÉÍÓÚÑ¿¡".Contains(c))
                || SpanishWords.Any(word => StartsWithWord(value, word))
                || CatalogOnlySpanish.Value.Any(text => StartsWithWord(value, text)));
    }

    private static bool StartsWithWord(string value, string word) =>
        value.StartsWith(word, StringComparison.Ordinal)
        && (value.Length == word.Length || !char.IsLetterOrDigit(value[word.Length]));

    private static string WithoutComment(string line)
    {
        var inString = false;
        for (var i = 0; i < line.Length - 1; i++)
        {
            if (line[i] == '\\' && inString)
            {
                i++;
            }
            else if (line[i] == '"')
            {
                inString = !inString;
            }
            else if (!inString && line[i] == '/' && line[i + 1] == '/')
            {
                return line[..i];
            }
        }

        return line;
    }

    // Strings of the Spanish catalog that neither English nor Portuguese uses as they are, so `Tab` and `Win` stay out.
    private static IReadOnlyList<string> SpanishOnlyCatalogStrings()
    {
        var others = Texts.All.Where(texts => texts.Language != AppLanguage.Es).SelectMany(Strings).ToHashSet();
        return Strings(Texts.Es).Where(text => text.Length >= 3 && !others.Contains(text)).Distinct().ToList();
    }

    private static IEnumerable<string> Strings(Texts texts)
    {
        foreach (var property in typeof(Texts).GetProperties())
        {
            switch (property.GetValue(texts))
            {
                case string text:
                    yield return text;
                    break;
                case IReadOnlyList<string> names:
                    foreach (var name in names)
                    {
                        yield return name;
                    }

                    break;
            }
        }
    }

    private static string RepositoryApp()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !Directory.Exists(Path.Combine(directory.FullName, "src", "DailyZGT.Core")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? throw new DirectoryNotFoundException("apps/windows was not found above the test output.");
    }
}

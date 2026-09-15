using Radzen;

namespace Sample.Web.Customers;

/// <summary>Maps grid paging arguments and the search box to a service query.</summary>
public sealed record CustomerQuery(int Skip, int Take, string? Name)
{
    public const int DefaultPageSize = 20;

    public static CustomerQuery From(LoadDataArgs args, string? name) =>
        new(args.Skip ?? 0, args.Top ?? DefaultPageSize, string.IsNullOrWhiteSpace(name) ? null : name.Trim());
}

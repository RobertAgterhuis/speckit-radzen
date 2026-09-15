namespace Sample.Web.Customers;

public sealed record CustomerSummary(int Id, string Name, string City);

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Total);

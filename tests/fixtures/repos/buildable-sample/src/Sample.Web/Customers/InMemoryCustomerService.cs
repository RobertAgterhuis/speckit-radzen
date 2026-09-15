namespace Sample.Web.Customers;

public sealed class InMemoryCustomerService : ICustomerService
{
    private static readonly IReadOnlyList<CustomerSummary> Data =
        Enumerable.Range(1, 250).Select(i => new CustomerSummary(i, $"Customer {i:D3}", i % 2 == 0 ? "Amsterdam" : "Utrecht")).ToList();

    public Task<PagedResult<CustomerSummary>> GetPageAsync(int skip, int take, string? nameContains, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        IEnumerable<CustomerSummary> query = Data;
        if (!string.IsNullOrWhiteSpace(nameContains))
        {
            query = query.Where(c => c.Name.Contains(nameContains, StringComparison.OrdinalIgnoreCase));
        }

        var filtered = query.ToList();
        return Task.FromResult(new PagedResult<CustomerSummary>(filtered.Skip(skip).Take(take).ToList(), filtered.Count));
    }
}

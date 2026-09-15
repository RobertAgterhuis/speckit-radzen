namespace Sample.Web.Customers;

public interface ICustomerService
{
    Task<PagedResult<CustomerSummary>> GetPageAsync(int skip, int take, string? nameContains, CancellationToken cancellationToken = default);
}

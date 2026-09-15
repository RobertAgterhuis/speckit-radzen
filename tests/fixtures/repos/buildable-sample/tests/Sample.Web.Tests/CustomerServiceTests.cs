using Sample.Web.Customers;
using Xunit;

namespace Sample.Web.Tests;

public class CustomerServiceTests
{
    [Fact]
    public async Task GetPageAsync_returns_requested_page_and_total()
    {
        var service = new InMemoryCustomerService();
        var page = await service.GetPageAsync(10, 5, null);
        Assert.Equal(5, page.Items.Count);
        Assert.Equal(250, page.Total);
        Assert.Equal(11, page.Items[0].Id);
    }

    [Fact]
    public async Task GetPageAsync_filters_on_name()
    {
        var service = new InMemoryCustomerService();
        var page = await service.GetPageAsync(0, 100, "Customer 00");
        Assert.Equal(9, page.Total);
    }
}

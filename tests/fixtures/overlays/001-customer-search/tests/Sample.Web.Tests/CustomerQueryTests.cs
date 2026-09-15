using Radzen;
using Sample.Web.Customers;
using Xunit;

namespace Sample.Web.Tests;

public class CustomerQueryTests
{
    [Fact]
    public void First_page_maps_skip_and_take()
    {
        var query = CustomerQuery.From(new LoadDataArgs { Skip = 0, Top = 20 }, null);
        Assert.Equal(new CustomerQuery(0, 20, null), query);
    }

    [Fact]
    public void Missing_paging_values_use_defaults()
    {
        var query = CustomerQuery.From(new LoadDataArgs(), "  ");
        Assert.Equal(new CustomerQuery(0, CustomerQuery.DefaultPageSize, null), query);
    }

    [Fact]
    public async Task Second_page_returns_items_21_to_40()
    {
        var query = CustomerQuery.From(new LoadDataArgs { Skip = 20, Top = 20 }, null);
        var page = await new InMemoryCustomerService().GetPageAsync(query.Skip, query.Take, query.Name);
        Assert.Equal(21, page.Items[0].Id);
        Assert.Equal(40, page.Items[^1].Id);
        Assert.Equal(250, page.Total);
    }

    [Fact]
    public async Task Name_filter_is_trimmed_and_applied()
    {
        var query = CustomerQuery.From(new LoadDataArgs { Skip = 0, Top = 20 }, " customer 00 ");
        Assert.Equal("customer 00", query.Name);
        var page = await new InMemoryCustomerService().GetPageAsync(query.Skip, query.Take, query.Name);
        Assert.Equal(9, page.Total);
    }
}

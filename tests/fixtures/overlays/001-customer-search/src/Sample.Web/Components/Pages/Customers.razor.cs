using Microsoft.AspNetCore.Components;
using Radzen;
using Radzen.Blazor;
using Sample.Web.Customers;

namespace Sample.Web.Components.Pages;

public partial class Customers
{
    private RadzenDataGrid<CustomerSummary>? grid;
    private IEnumerable<CustomerSummary> customers = [];
    private int count;
    private bool isLoading;
    private string? nameFilter;

    [Inject] private ICustomerService CustomerService { get; set; } = default!;

    private async Task LoadDataAsync(LoadDataArgs args)
    {
        isLoading = true;
        try
        {
            var query = CustomerQuery.From(args, nameFilter);
            var page = await CustomerService.GetPageAsync(query.Skip, query.Take, query.Name);
            customers = page.Items;
            count = page.Total;
        }
        finally
        {
            isLoading = false;
        }
    }

    private async Task OnSearchAsync(string value)
    {
        nameFilter = value;
        if (grid is not null)
        {
            await grid.FirstPage(true);
        }
    }
}

using Contoso.Crm.Web.Components;
using Microsoft.Identity.Web;
using Radzen;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthentication().AddMicrosoftIdentityWebApp(builder.Configuration);
builder.Services.AddAuthorization(o => o.AddPolicy("CustomersRead", p => p.RequireRole("Sales")));
builder.Services.AddRazorComponents().AddInteractiveServerComponents();
builder.Services.AddRadzenComponents();
builder.Services.AddProblemDetails();

var app = builder.Build();
app.UseAntiforgery();
app.MapGet("/api/customers", () => Results.Ok()).RequireAuthorization("CustomersRead");
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
app.Run();

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorComponents().AddInteractiveServerComponents();
builder.Services.AddRadzenComponents();
builder.Services.AddMediatR(c => c.RegisterServicesFromAssemblyContaining<Program>());
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
var app = builder.Build();
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
app.Run();

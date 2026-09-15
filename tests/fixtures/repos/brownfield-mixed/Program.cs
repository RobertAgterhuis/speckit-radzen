var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorComponents();
builder.Services.AddControllers();
var app = builder.Build();
app.MapGet("/api/ping", () => "pong");
app.MapControllers();
app.MapRazorComponents<App>();
app.Run();

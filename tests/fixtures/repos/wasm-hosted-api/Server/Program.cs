var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddAuthentication().AddJwtBearer();
var app = builder.Build();
app.UseBlazorFrameworkFiles();
app.MapControllers();
app.MapFallbackToFile("index.html");
app.Run();

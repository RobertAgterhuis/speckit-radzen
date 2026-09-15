public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddServerSideBlazor();
        services.AddScoped<Radzen.DialogService>();
    }
    public void Configure(IApplicationBuilder app)
    {
        app.UseEndpoints(e => { e.MapBlazorHub(); e.MapFallbackToPage("/_Host"); });
    }
}

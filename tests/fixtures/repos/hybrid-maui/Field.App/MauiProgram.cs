public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder.Services.AddMauiBlazorWebView();
        builder.Services.AddRadzenComponents();
        return builder.Build();
    }
}

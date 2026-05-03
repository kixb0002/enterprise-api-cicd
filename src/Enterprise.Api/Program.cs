using System.Reflection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddHealthChecks();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.MapHealthChecks("/health");

app.MapGet("/ready", () =>
{
    return Results.Ok(new
    {
        status = "ready",
        time = DateTime.UtcNow
    });
});

app.MapGet("/version", () =>
{
    var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "unknown";

    return Results.Ok(new
    {
        app = "enterprise-api",
        version,
        environment = app.Environment.EnvironmentName,
        time = DateTime.UtcNow
    });
});

app.MapGet("/api/products", () =>
{
    var products = new[]
    {
        new { Id = 1, Name = "Laptop", Price = 1200 },
        new { Id = 2, Name = "Keyboard", Price = 80 },
        new { Id = 3, Name = "Mouse", Price = 40 }
    };

    return Results.Ok(products);
});

app.MapGet("/api/products/{id:int}", (int id) =>
{
    if (id <= 0)
    {
        return Results.BadRequest(new { message = "Invalid product id" });
    }

    return Results.Ok(new
    {
        Id = id,
        Name = $"Product {id}",
        Price = 100 + id
    });
});

app.Run();

public partial class Program { }
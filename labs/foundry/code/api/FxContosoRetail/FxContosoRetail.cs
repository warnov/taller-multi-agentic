using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Contoso.Retail.Functions;

public class FxContosoRetail
{
    private readonly ILogger<FxContosoRetail> _logger;

    public FxContosoRetail(ILogger<FxContosoRetail> logger)
    {
        _logger = logger;
    }

    [Function("HolaMundo")]
    public IActionResult Run(
        [HttpTrigger(AuthorizationLevel.Function, "get")] HttpRequest req)
    {
        _logger.LogInformation("Función HolaMundo ejecutada.");
        return new OkObjectResult("¡Hola Mundo!");
    }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
[ApiController]
[Authorize]
[Route("api/[controller]")]
public class InvoicesController : ControllerBase { }

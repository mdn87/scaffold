# Project Inventory: SpecRebuilder_v0.2

- Target: ./SpecRebuilder_v0.2
- Generated: 2026-03-13 15:54:35
- Recommendation: map
- Type hints: agent-rules, dotnet, solution, static-web-assets

## Rules

- `.agent\rules\always-approve-whitelisted-commands.md`
- `.agent\rules\quota-drain-prevention.md`
- `.agent\rules\restart-api-host-as-needed.md`
- `.agents\always-approve-whitelisted-commands.md`
- `.agents\quota-drain-prevention.md`
- `.agents\restart-api-host-as-needed.md`
- `.agents\rules.md`

## Manifests

- `OOXML-Validator\OOXMLValidator.sln`
- `OOXML-Validator\OOXMLValidatorCLI\OOXMLValidatorCLI.csproj`
- `OOXML-Validator\OOXMLValidatorCLITests\OOXMLValidatorCLITests.csproj`
- `SpecRebuilder_v0.2.csproj`
- `SpecRebuilder_v0.2.sln`
- `src\Tools\BwaStyleCli\BwaStyleCli.csproj`

## Baseline Alignment

- dir `docs`: True
- dir `src`: True
- dir `tests`: False
- file `.gitignore`: True
- file `README.md`: True

## Likely Interfaces

- `src\API\StyleApiController.cs:12` - [Route("api/style")]
- `src\API\StyleApiController.cs:25` - [HttpGet("templates")]
- `src\API\StyleApiController.cs:42` - [HttpPost("templates/base/generate")]
- `src\API\StyleApiController.cs:63` - [HttpPost("templates/playground/generate")]
- `src\API\StyleApiController.cs:89` - [HttpPost("templates/validate/{clientName}")]
- `src\API\StyleApiController.cs:111` - [HttpPost("documents/validate")]
- `src\API\StyleApiController.cs:181` - [HttpGet("templates/{clientName}/download")]
- `src\API\StyleApiController.cs:209` - [HttpPost("templates/upload")]
- `src\API\StyleApiController.cs:246` - [HttpGet("playgrounds/{clientName}/download")]
- `src\API\StyleApiController.cs:273` - [HttpPost("templates/create-from-json")]
- `src\API\StyleApiController.cs:299` - [HttpPost("apply-json")]
- `src\API\StyleApiController.cs:353` - [HttpPost("apply")]
- `src\API\StyleApiController.cs:402` - [HttpPost("apply-batch")]
- `src\API\VisualizerApi.cs:74` - app.MapGet("/api/config", () =>
- `src\API\VisualizerApi.cs:96` - app.MapGet("/api/exports", () =>
- `src\API\VisualizerApi.cs:160` - app.MapGet("/api/jobs/{id}", (string id) =>
- `src\API\VisualizerApi.cs:170` - app.MapGet("/api/chunks/{documentId}", async (string documentId) =>
- `src\API\VisualizerApi.cs:219` - app.MapPost("/api/analyze", async (HttpRequest request) =>
- `src\API\VisualizerApi.cs:453` - app.MapPost("/api/export", async (HttpContext context) =>
- `src\API\VisualizerApi.cs:562` - app.MapGet("/api/stylegroups", () =>


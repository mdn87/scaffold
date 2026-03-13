# Interface Map: SpecRebuilder_v0.2

- Target: ./SpecRebuilder_v0.2
- Generated: 2026-03-13
- Based on: Full crawl of `src/API/StyleApiController.cs` (470 lines) and `src/API/VisualizerApi.cs` (1305 lines)
- Total endpoints: 29 across 7 groups (was 5 groups with 12 in "other-api")

## Host Entry

- File: `Program.cs`
- Trigger: `dotnet run --api`
- Delegates to: `VisualizerApi.CreateApiApp()`
- Port: 5000
- Registration: MVC controllers via `app.MapControllers()`, Minimal API inline, static files via `app.UseStaticFiles()`

---

## 1. Template Management (9 endpoints)

Owner: `src/API/StyleApiController.cs` · Prefix: `api/style` · Service: `StyleService`

CRUD and generation for BWA-style Word templates (.dotx). Manages base templates, client-specific templates, and playground documents.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| GET | `api/style/templates` | 25 | List all templates |
| POST | `api/style/templates/base/generate` | 42 | Generate BWA base template |
| POST | `api/style/templates/playground/generate` | 63 | Generate client playground document |
| POST | `api/style/templates/validate/{clientName}` | 89 | Validate a client template |
| DELETE | `api/style/templates/{clientName}` | 157 | Delete a client template |
| GET | `api/style/templates/{clientName}/download` | 181 | Download a client template (.dotx) |
| POST | `api/style/templates/upload` | 209 | Upload a client template (.dotx) |
| POST | `api/style/templates/create-from-json` | 273 | Create template from JSON style definitions |
| GET | `api/style/playgrounds/{clientName}/download` | 246 | Download a playground document (.docx) |

## 2. Document Style Application (4 endpoints)

Owner: `src/API/StyleApiController.cs` · Prefix: `api/style` · Service: `StyleService`

Apply style templates to uploaded Word documents. Supports single-file, batch, and ad-hoc JSON-based style application.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| POST | `api/style/documents/validate` | 111 | Validate an uploaded Word document |
| POST | `api/style/apply` | 353 | Apply client template styles to uploaded .docx |
| POST | `api/style/apply-json` | 299 | Apply ad-hoc JSON styles to uploaded .docx |
| POST | `api/style/apply-batch` | 402 | Apply template to multiple .docx files, return ZIP |

## 3. Analysis Pipeline (3 endpoints)

Owner: `src/API/VisualizerApi.cs` · Prefix: `api` · Service: `SourceDecodingService`

Upload Word documents for AI-powered source decoding analysis. Supports first-time and iterative re-analysis with user feedback. Background job model with polling.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| POST | `api/analyze` | 219 | Upload .docx and start analysis job (background) |
| GET | `api/jobs/{id}` | 160 | Poll job status and progress |
| GET | `api/chunks/{documentId}` | 170 | Retrieve cached chunk data from ready folder |

## 4. Export Pipeline (3 endpoints)

Owner: `src/API/VisualizerApi.cs` · Prefix: `api` · Service: `OpenXmlDocumentExporter`, `TemplateManager`

Export edited chunks back to Word documents. Optionally applies client template skin. Persists chunks to ready folder for reload.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| POST | `api/export` | 453 | Export chunks to .docx with optional template skin |
| GET | `api/exports` | 96 | List available export JSON files (ready folder) |
| GET | `api/export-report/{documentName}` | 924 | Get last export data report block for a document |

## 5. Style Group Library (5 endpoints)

Owner: `src/API/VisualizerApi.cs` · Prefix: `api/stylegroups` · Service: `StyleGroup` (model with factory methods)

Full CRUD for style group presets (CSI, BWA, RPA built-ins + user-created). Persisted as JSON files in `examples/stylegroups`.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| GET | `api/stylegroups` | 562 | List all style groups (built-in + custom) |
| GET | `api/stylegroups/{id}` | 617 | Load a specific style group |
| POST | `api/stylegroups` | 659 | Create a new custom style group |
| PUT | `api/stylegroups/{id}` | 709 | Update an existing custom style group |
| DELETE | `api/stylegroups/{id}` | 757 | Delete a custom style group |

## 6. Per-Document Styles (3 endpoints)

Owner: `src/API/VisualizerApi.cs` · Prefix: `api/styles` · Service: `StyleConfiguration` (model)

Load and save style configuration for a specific analyzed document. Falls back to `StyleConfiguration.CreateDefault()` when no saved config exists.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| GET | `api/styles/{documentId}` | 789 | Load saved style config (or default) |
| POST | `api/styles/{documentId}` | 826 | Save style config for a document |
| GET | `api/style/css/{clientName}` | 909 | Extract CSS properties from a client template |

## 7. Diagnostics (2 endpoints)

Owner: `src/API/VisualizerApi.cs` · Prefix: `api` · Service: `VisualizerDiscrepancyTracker`, `AppSettings`

Operational and diagnostic endpoints for the visualizer pipeline.

| Method | Route | Line | Purpose |
|--------|-------|------|---------|
| GET | `api/config` | 74 | Get runtime config (exports folder path, etc.) |
| GET | `api/visualizer/discrepancies/{sessionId}` | 871 | Retrieve analysis-to-visualizer discrepancy log |

---

## Static Assets

- Root: `wwwroot`
- Entry point: `wwwroot/index.html`
- Served by: `app.UseDefaultFiles()` + `app.UseStaticFiles()`
- Single-page visualizer UI, registered after API routes to avoid route conflicts.

## Architecture Notes

1. Two API registration styles coexist: MVC controller (`StyleApiController`) and Minimal API (`VisualizerApi`). Both registered in `CreateApiApp()`.
2. `StyleApiController` instantiates `StyleService` directly (no DI). `VisualizerApi` inline-resolves its dependencies.
3. Analysis pipeline uses `Task.Run` with an in-memory `ConcurrentDictionary<string, AnalysisJob>` job store — jobs do not survive process restart.
4. File I/O is heavy: exports, ready folder, stylegroups, templates, playgrounds all use project-root-relative paths with bin-folder fallback logic.
5. CORS is fully open (`AllowAnyOrigin`) — appropriate for local-only dev tool, would need lockdown if exposed.

## How "other-api" Was Resolved

| Previous Group | Count | Resolved To |
|----------------|-------|-------------|
| style-template-api (9) | 9 | Template Management (9) |
| other-api (12) | 12 | Template Management (+partial), Document Style Application (4), Per-Document Styles (1) |
| config-api (1) | 1 | Diagnostics (2) |
| analysis-export-api (6) | 6 | Analysis Pipeline (3) + Export Pipeline (3) |
| visualizer-api (1) | 1 | Diagnostics (2) |

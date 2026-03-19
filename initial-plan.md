Yes. What you want is basically an AI-readable system map of the project so the model stops wasting tokens rediscovering architecture every time.

That is worth doing for a project like yours, especially if you keep hitting quota on agent tools. But it only pays off if you keep it structured, scoped, and cheap to maintain. If you try to document everything in prose, you will just create another bloated artifact the model has to reread.

The right approach is not a giant narrative doc. It is a small set of machine-friendly files.

A practical setup would look like this:

/ai-context/project-map.md
High-level architecture. Very short. What the app does, major subsystems, data flow, critical invariants.

/ai-context/file-index.json
A structured map of important files, what each file owns, what it depends on, and what must not be broken.

/ai-context/domain-rules.md
Business logic and non-obvious rules. For your case, this is where spec structure logic lives, like PART/SECTION/ARTICLE assumptions, numbering rules, list reconstruction constraints, style mapping rules, fallback behavior.

/ai-context/contracts.json
Backend to frontend contracts. Endpoints, request/response shapes, DTOs, enums, validation rules.

/ai-context/change-log.md
Human-readable log of meaningful architectural changes, not every tiny edit.

/ai-context/current-focus.md
What is actively being worked on right now, known bugs, temporary compromises, next priorities.

That is the useful version. Not fifty docs.

For the “project table of context type thing,” I would make the center of it a dependency and responsibility matrix. Something like this:

Area	File/module	Responsibility	Inputs	Outputs	Depends on	Used by	Notes

And for backend/frontend wiring specifically:

| Feature | Backend route/service | DTO/schema | Frontend store/composable | UI component | Status |

That lets an AI answer questions like:

what backend logic powers this Vue component

what breaks if I rename this field

where should new validation live

what files need updating for a new feature

That is exactly the kind of thing that reduces context burn.

The one-time cost is usually worth it if:

the codebase is medium or larger

you revisit the same areas repeatedly

multiple files participate in one feature

the agent keeps rescanning the same repo

architecture matters more than raw code generation

For SpecRebuilder_v0.2, that sounds like yes. Especially because your app is not just CRUD. It has interconnected parsing, reconstruction, style logic, probably output logic, and a frontend layer. Those projects get expensive fast when the AI has to infer structure from scratch every session.

What you should not expect is full automation from one static context pack. The AI still needs the relevant source files for actual edits. The context pack just tells it where to look and what not to misunderstand.

For keeping the docs updated, there are three levels.

Level 1 is the cheapest and most realistic:
Add a rule that every meaningful code change must also update the relevant AI context file. Treat it like updating a README or type contract. This works if you are disciplined.

Level 2 is better:
Use a pull request or commit checklist. Example:

changed architecture?

changed API contract?

changed file ownership/responsibility?

changed business rule?

if yes, update /ai-context/*

That catches drift without much cost.

Level 3 is semi-automated:
Write a script that scans the codebase and regenerates the cheap structured parts, like file lists, imports, route maps, schema references, maybe Vue component usage. Then keep the high-value semantic docs human-maintained.

That is usually the sweet spot.

Do not try to fully auto-generate the entire context system from code on every change. That tends to produce noisy garbage and burns tokens for little gain.

For example, a good hybrid setup is:

script regenerates file-index.json

script extracts route and schema references into contracts.json

you manually maintain domain-rules.md and project-map.md

current-focus.md is updated only when priorities shift

That keeps ongoing cost under control.

As for “set rules to update that documentation whenever changes are made,” do it in two places:

First, in a repo instruction file the AI sees, such as AGENTS.md or similar. Put rules like:

When modifying architecture, contracts, domain logic, or module responsibilities, also update the corresponding file in /ai-context.

Update rules:
- API or DTO changes -> update /ai-context/contracts.json
- File responsibility changes -> update /ai-context/file-index.json
- Domain logic or parsing rules change -> update /ai-context/domain-rules.md
- Major architecture changes -> update /ai-context/project-map.md
- Active priorities or known issues change -> update /ai-context/current-focus.md

Do not make unrelated documentation edits.
Keep updates minimal and specific to the change made.

Second, in your own workflow:
Before commit, or before accepting an AI patch, ask:
“Did this change invalidate any AI context docs?”

That is enough most of the time.

Would updating-as-changing-happens blow up the budget? Not if you keep it targeted.

What blows up the budget is:

forcing the AI to rewrite big context docs every task

including the full context pack in every prompt

auto-summarizing the whole repo after every commit

maintaining redundant docs that say the same thing differently

What stays cheap is:

a few structured files

only updating the one affected doc

only feeding the AI the relevant slice of context for the task

The whole point is to move from “read everything again” to “read the map, then inspect these two files.”

My blunt take: yes, build this once. It is one of the few “AI documentation” efforts that can actually pay for itself on a project like yours. But keep it narrow, structured, and partly automated. If you overengineer it into a living encyclopedia, it will become expensive and stale.

A solid minimal starter pack for you would be:

project-map.md

file-index.json

contracts.json

domain-rules.md

current-focus.md

That is enough to materially reduce context waste.
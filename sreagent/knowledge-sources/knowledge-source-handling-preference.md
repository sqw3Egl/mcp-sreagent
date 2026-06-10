# Knowledge source handling preference

User instruction:

When the user asks to add or save knowledge for Azure SRE Agent, prefer adding it to the agent's portal-managed knowledge base first when a supported upload path is available, instead of only creating a local workspace file.

Operational rules:

- Treat local workspace files as local-only unless explicitly requested.
- If a knowledge item is important for future sessions, also persist the durable behavior or lesson in agent memory when appropriate.
- Be explicit about the distinction between local workspace files, remote repository changes, and portal-managed knowledge.
- Do not claim a portal knowledge source was added unless it was actually uploaded to the agent knowledge base or otherwise registered through a supported portal/API path.

Why this matters:

This avoids confusion when something exists only in the local workspace but is not visible in the Azure SRE Agent portal.

Source:

Direct user instruction in conversation on 2026-06-10.

---
name: github-code-reading
description: |
  Use this skill when the user wants to read, inspect, or summarize files or directory trees from a GitHub repository through the GitHub App-backed read-only tool. It guides the agent to gather the minimum required inputs, prefer exact file reads unless the user explicitly asks for a broader root-path read, and keep authentication details out of normal tool inputs and responses.
tools:
  - GithubConnectionEmulator
---

# GitHub Code Reading Skill

## Purpose

Use the `GithubConnectionEmulator` tool to read repository files through GitHub App authentication without exposing private key material in the conversation or per-call inputs.

## When This Skill Applies

Use this skill when the user asks to:
- read the contents of a specific file from a GitHub repository
- inspect code, configuration, workflows, or documentation in a repository
- summarize or explain a repository file after fetching it from GitHub
- read a directory root recursively to inspect multiple text files under that path

Do not use this skill for:
- creating commits, pull requests, or issues
- changing repository contents
- broad repository crawling when the user only needs one or two files

## Required Inputs

Before calling the tool, make sure you have:
- `org`
- `repo`
- `path`

Optional:
- `ref` when the user wants a branch, tag, or commit SHA other than the default branch
- `maxBytes`, `maxFiles`, or `maxTotalBytes` when the user wants to control truncation or breadth for directory reads

If one of the required values is missing, ask a short pointed question to get it.

## Operating Rules

1. Prefer exact file reads unless the user asked for a broader root-path read.
   - If the user names a file path, call the tool directly.
   - Do not guess or invent file contents.

2. Keep scope tight.
   - Avoid broad scans unless the user explicitly asks for exploration or a directory-root read.
   - If the path is uncertain, ask for the path or use a directory-listing helper if one exists.

3. Keep auth details out of normal flow.
   - Do not ask the user for the GitHub App private key in chat.
   - Do not echo installation tokens, JWTs, or secret values.
   - The tool runtime configuration is responsible for Key Vault access and token exchange.

4. Handle large results safely.
   - Respect truncation behavior.
   - If a result is truncated, say so clearly and suggest narrowing the path or adjusting the size limits.

5. Stay read-only.
   - Do not imply that this skill can modify files or create repository artifacts.

## Basic Workflow

1. Confirm `org`, `repo`, and `path`.
2. Use `ref` if the user specified a branch, tag, or commit.
3. Call `github_app_read_file`.
4. Summarize the file contents or answer the user's question about the file or directory root.
5. If the tool returns a normalized error such as `not_found`, `ref_not_found`, or `access_denied`, explain that directly and suggest the smallest useful next step.

## Output Guidance

After fetching a path:
- briefly confirm which path and ref were read
- if the path is a file, summarize the file or answer the specific question asked
- if the path is a directory, summarize the most relevant files returned and mention skipped files or truncation
- avoid dumping very large content unless the user explicitly asks for it

## Safety Notes

- Treat repository contents as potentially sensitive.
- Do not surface secrets even if they appear in a file.
- Prefer summaries and narrow excerpts when the user does not need the full file set.

## Example Use Cases

- "Read `src/server.ts` from `contoso/payments-api`."
- "Show me `.github/workflows/deploy.yml` from repo `platform-infra`."
- "Summarize the config in `app/settings.py` on branch `release/2026-06`."
- "Read everything under `sreagent/` so I can inspect that subtree."

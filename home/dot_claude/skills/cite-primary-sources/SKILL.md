---
name: cite-primary-sources
description: Verify technical claims against primary sources (specs, official docs, source code) and cite links inline. TRIGGER when answering technical questions about external systems (APIs, libraries, protocols, specs) or summarizing research findings.
allowed-tools: WebFetch WebSearch Read Grep
---

# cite-primary-sources

Ground technical answers in verifiable primary sources, and surface the link so the user can confirm independently. The deliverable is an answer where every external-fact claim has a checkable origin.

## When to use

- Questions about how a tool, API, library, protocol, or spec behaves
- Research summaries, comparison tables, "which option should I pick" investigations
- Claims about syntax, configuration defaults, version differences, deprecations
- Any factual statement about a system outside the current repo

## When NOT to use

- Opinions, design discussions, judgment calls
- Code-style preferences with no canonical source
- Project-internal questions (answer from the repo itself, not the web)
- Trivial clarifications inside the current conversation context

## Source priority

Use the highest tier that covers the claim. Drop down only when the higher tier is unreachable.

| Tier | Examples                                                                |
| ---- | ----------------------------------------------------------------------- |
| 1    | Spec / RFC / standard (RFC, W3C, ECMA, IETF, ISO)                       |
| 2    | Official documentation (vendor docs site, language reference, man page) |
| 3    | Source code in the authoritative repo (pinned to a tag/commit)          |
| 4    | Official release notes, changelogs, migration guides, vendor blog       |
| 5    | Secondary sources (Stack Overflow, Qiita, Zenn, personal blog)          |

Tier 5 is **supporting context only** — never the sole source for a factual claim.

## Workflow

1. **Identify factual claims** in the answer being drafted. Anything about external system behavior is a candidate.
2. **Search and fetch** the highest-tier source available with `WebSearch` → `WebFetch`. Confirm the page actually contains the claim before citing.
3. **Quote or paraphrase faithfully**. Do not extrapolate beyond what the source states.
4. **Cite the URL inline** at the point the claim is made (preferred), or in a 参照 list at the end for research summaries.
5. **If no primary source can be located**, say so explicitly. Mark the claim as "未確認" or "記憶ベース" rather than asserting it as fact.

## Citation format

Inline citation (default):

```markdown
HTTP/2 はストリームを単一の TCP 接続で多重化する ([RFC 7540 §5](https://www.rfc-editor.org/rfc/rfc7540#section-5))。
```

Research summary footer:

```markdown
## 参照
- [RFC 7540 - HTTP/2](https://www.rfc-editor.org/rfc/rfc7540)
- [MDN - Evolution of HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Evolution_of_HTTP)
```

For source code citations, link to a tagged commit or release-pinned path:

```markdown
([next.js v15.0.0 / packages/next/src/server/app-render.tsx#L42](https://github.com/vercel/next.js/blob/v15.0.0/packages/next/src/server/app-render.tsx#L42))
```

## Operating principles

- **Do not fabricate URLs.** If `WebSearch` did not return the canonical page, fetch a candidate and verify before citing. Plausible-looking URLs invented from memory are forbidden.
- **Pin versions** when behavior is version-dependent. A link to `latest` docs may silently rot; a tagged link is durable.
- **Separate fact from synthesis.** Sourced facts and your own recommendations should be visually distinguishable (e.g., "出典あり" vs "ウニの判断:").
- **Cross-check when contested.** Rapidly evolving topics (frameworks, browser APIs in flux) warrant two independent primary sources.
- **Trust the source over memory.** If a fetch contradicts what you recalled, update the answer; do not split the difference.
- **One language for the answer, original language for sources.** Cite English specs in their original form even when the answer is in Japanese.

## Edge cases

- **Source paywalled or login-gated** → cite the URL anyway and note the access restriction; do not paraphrase from a cached secondary source as if it were primary.
- **Source not found** → state "一次ソース未確認" and offer the best secondary explanation, clearly marked.
- **Conflicting primary sources** → cite both and surface the conflict; do not silently pick one.
- **Source is the user's own repo** → use `Read` / `Grep` and cite `path:line` instead of a URL.

# What Is Agent Registry? — YouTube Script

**Target length:** ~4 minutes (~550 spoken words)
**Tone:** Educational explainer, not a product pitch
**Links:** https://aregistry.ai · https://github.com/agentregistry-dev/agentregistry

---

## 0:00 — OPEN (0:00–0:25)

**[VISUAL: clean title card or whiteboard-style intro]**

**HOST:**
> When you build an AI agent, you're not really building one thing. You're assembling several. There's the agent's identity, the prompts it runs on, the skills it has, and the tools it can call out to through MCP servers.

> Each of those pieces is its own artifact. And right now, most teams don't have a good place to store them. That's the gap **Agent Registry** is built to fill. Let's walk through what it actually is.

---

## 0:25 — THE PROBLEM: SCATTERED AI ARTIFACTS (0:25–1:10)

**[VISUAL: diagram of artifacts spread across npm, PyPI, Docker Hub, GitHub, local folders]**

**HOST:**
> Today, the building blocks of an AI agent live in a lot of different places.

> An MCP server might be published as an npm package. Another one might be a Python package on PyPI. A third might be a Docker image on Docker Hub, or just a script someone wrote and put in a GitHub repo.

> Skills — which are structured packages of instructions and reference material that teach an agent how to do a specific task — usually live in folders on someone's laptop, or buried in a private repository.

> Agent definitions and prompt templates often aren't versioned at all. They're copy-pasted between developers.

> So when a new person joins the team and wants to use the same setup, there's no single place to look. They have to track down each piece manually, figure out which version, set the right environment variables, and configure their IDE by hand. That's the problem.

---

## 1:10 — WHAT AGENT REGISTRY IS (1:10–2:00)

**[VISUAL: same diagram, but all artifacts now flowing into a single registry box]**

**HOST:**
> Agent Registry is an open-source platform that gives those artifacts a single home. It's a registry — in the same sense that Docker Hub is a registry for container images, or npm is a registry for JavaScript packages — but built specifically for AI artifacts.

> It handles four artifact types: **MCP servers**, **agents**, **skills**, and **prompts**. You can pull MCP servers in from npm, PyPI, Docker images, or remote endpoints, and you can publish your own agents and skills directly.

> Every artifact in the registry is versioned. It carries metadata — environment variables, package references, quality scores. And there's one place to look at it: a web UI that runs on `localhost:12121`, or a command-line tool called `arctl`.

> So instead of "go find the right MCP server," it becomes "search the registry."

---

## 2:00 — HOW CENTRALIZATION ACTUALLY HELPS (2:00–2:55)

**[VISUAL: split into three labeled scenes — Discovery, Governance, Deployment]**

**HOST:**
> Centralizing artifacts in one registry changes three things in practice.

> **First, discovery.** Developers stop hunting across repos. They open the registry, search for what they need, and see what their organization has already approved.

> **Second, governance.** A platform team can curate the catalog — review artifacts before they're available company-wide, add context to help others judge whether something is trustworthy, and standardize how things get versioned and promoted. That's hard to do when artifacts are scattered. It's straightforward when they're in one place.

> **Third, deployment.** Because every artifact is described the same way, the path from "I found this" to "it's running and my IDE is using it" becomes consistent. The same workflow works on a laptop or on Kubernetes.

> The artifacts themselves don't change. What changes is the surface area around them — one catalog, one set of tools, one approval path.

---

## 2:55 — THE GATEWAY PIECE (2:55–3:30)

**[VISUAL: architecture diagram — registry feeding agentgateway, gateway connecting to Claude Desktop, Cursor, VS Code]**

**HOST:**
> One detail worth understanding — Agent Registry pairs with a companion project called **agentgateway**. The registry is where artifacts live. The gateway is how clients actually reach them.

> Instead of each IDE talking directly to every MCP server it needs, the IDE points at one gateway endpoint. The gateway handles authentication, routes the request to the correct backend, and logs the traffic.

> So the registry answers "what artifacts exist." The gateway answers "how do clients securely use them." Together they cover both halves of the workflow.

---

## 3:30 — WRAP-UP (3:30–4:00)

**[HOST direct to camera]**

> So to summarize — Agent Registry is an open-source registry for AI artifacts. It takes MCP servers, agents, skills, and prompts that today live across npm, PyPI, Docker Hub, and scattered repos, and gives them a single, versioned home with shared tooling around them.

> It's Apache 2.0, runs locally or in Kubernetes, and the project lives at `aregistry.ai` — links in the description if you want to dig deeper.

> Thanks for watching.

**[END CARD]**

---

## YouTube Description

> A walkthrough of Agent Registry — an open-source registry for AI artifacts (MCP servers, agents, skills, and prompts). We cover what the project is, the problem of scattered AI artifacts, and how centralization changes discovery, governance, and deployment.
>
> 🔗 Links
> • Website: https://aregistry.ai
> • GitHub: https://github.com/agentregistry-dev/agentregistry
> • Docs: https://aregistry.ai/docs/
>
> ⏱ Chapters
> 0:00 Intro
> 0:25 The problem: scattered AI artifacts
> 1:10 What Agent Registry is
> 2:00 How centralization helps
> 2:55 The gateway piece
> 3:30 Wrap-up
>
> #AI #MCP #AgentRegistry #OpenSource

## Title options

1. **What Is Agent Registry? A Centralized Home for AI Artifacts**
2. **Agent Registry, Explained: Centralizing MCP Servers, Agents, and Skills**
3. **How Agent Registry Solves the AI Artifact Sprawl Problem**
4. **A Registry for AI Artifacts — Agent Registry in 4 Minutes**

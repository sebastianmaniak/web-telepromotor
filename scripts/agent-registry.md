# Agent Registry — Lightboard Session

3–5 min · Platform / DevOps audience · What it is, what it solves, how to start

This doc is split into two areas. **Area 1 — The Script** is the words you say, panel by panel, with light stage cues. **Area 2 — The Drawings** is every draw instruction in order, plus reference diagrams.

---

# Area 1 — The Script

## Intro

[Look at camera, no drawing yet.]

Hey — I'm Sebastian Maniak.


Today I want to walk you through a project called Agent Registry — what it is, what it solves for platform teams, and how you get started.


## Panel 1 — the problem

Let's start with where most teams are right now. On one side of the board, you've got your developers. On the other, the new building blocks they need to ship agentic apps — MCP servers, agents, and skills. And those are showing up faster than anyone can vet them.

So what ends up happening? Every developer wires themselves up to whichever ones they need. Different teams pin different versions of the same server. Someone on the team is already running an MCP server they npx-installed off a GitHub repo they found yesterday. And nobody — really, nobody — owns that supply chain.

Now, if you put your platform-engineering hat on for a second, that picture really comes down to four problems.

The first one is trust. Is this artifact actually safe to run inside our walls? The second is versions — what's pinned where, and can we roll it back if it breaks? The third is governance — who's even allowed to publish these things, and who's allowed to pull them down? And the fourth is discovery. When a new developer joins your team, how do they find the approved set without DM'ing a senior engineer?

We solve this issue with a central AI Artifcatory.. called agent registry.. It's an open source catalog for your AI 


The whole idea is one central place that hosts your  AI articfacts: 
Agents, MCP servers, skills, prompts — all cataloged the same way. Publish with one CLI command or your existing git ops process. Search by name or by *meaning* .  Push/pull into yout Kubernetes infrascutrue, and consumed by your agents, claude code, cursor, grok build, wherever you need it."

The catalogue is curated by your organization, you govern who can publish and who can pull 

You score and entruch the metadata,, 

So when a team deploys a mcp server you actually know what it does and how trusted it is.. 

submitted ──▶ [REVIEW] ──▶ approved ──▶ prod

 "And nothing reaches production without going through review. Audit trail included."

So let's jump into a demo..


## Wrap

So that's Agent Registry. If you take one thing away, it's this: it brings the registry-and-gateway pattern you already trust for containers to the AI stack — so your platform team can ship agents to production with the same kind of controls you'd put on any other piece of your software supply chain.

 
 For more information check out  `aregistry.ai`. 



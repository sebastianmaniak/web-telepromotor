# Agent Registry — Lightboard Session

3–5 min · Platform / DevOps audience · What it is, what it solves, how to start

This doc is split into two areas. **Area 1 — The Script** is the words you say, panel by panel, with light stage cues. **Area 2 — The Drawings** is every draw instruction in order, plus reference diagrams.

---

# Area 1 — The Script

## Intro

[Look at camera, no drawing yet.]

Hey — I'm Sebastian Maniak.

[Pause, gesture to the board.]

Today I want to walk you through a project called Agent Registry — what it is, what it solves for platform teams, and how you get started with it in about three commands.


## Panel 1 — the problem

Let's start with where most teams are right now. On one side of the board, you've got your developers. On the other, the new building blocks they need to ship agentic apps — MCP servers, agents, and skills. And those are showing up faster than anyone can vet them.

So what ends up happening? Every developer wires themselves up to whichever ones they need. Different teams pin different versions of the same server. Someone on the team is already running an MCP server they npx-installed off a GitHub repo they found yesterday. And nobody — really, nobody — owns that supply chain.

Now, if you put your platform-engineering hat on for a second, that picture really comes down to four problems.

The first one is trust. Is this artifact actually safe to run inside our walls? The second is versions — what's pinned where, and can we roll it back if it breaks? The third is governance — who's even allowed to publish these things, and who's allowed to pull them down? And the fourth is discovery. When a new developer joins your team, how do they find the approved set without DM'ing a senior engineer?

If that sounds familiar, it should. It's the same shape of problem we solved a decade ago for containers, with image registries — and for packages, with Artifactory and friends. The AI stack just doesn't have its version of that yet.


## Panel 2 — the fix

That's exactly what Agent Registry is. The whole idea is one central place that holds those three kinds of artifacts: MCP servers — which are your tool fleet; agents — packaged, signed, and versioned like any other piece of software you ship; and skills — the smaller, reusable pieces.

And around that registry, you've got four capabilities that your platform team is actually going to use. You curate the catalog — you decide what's in it. You govern who can publish and who can pull. You score and enrich the metadata, so when somebody runs a server you actually know what it does and how trusted it is. And you can deploy that catalog anywhere — laptop, cluster, prod, doesn't matter.

So how do people interact with it? On one side, your platform team — the operators — push approved artifacts in. They're the ones with write access. That's where your governance boundary lives.

On the other side, here's the move that really matters. Your developers don't talk to fifteen separate MCP servers anymore. They talk to one thing — the Agent Gateway. Whether it's their IDE, your CI system, or a production runtime, they all hit the same endpoint. Single auth surface. Single audit log. The gateway federates everything behind it.

And if you've done container platforms before, the mental model is the one you already know. The registry is your Harbor. The gateway is your ingress. The catalog is your set of approved base images. Same pattern you already trust — just applied to the AI stack.


## Panel 3 — getting started

Okay, so how do you actually try this? It really is three commands.

Step one — install the CLI. One curl line, and you get a single Go binary called `arctl`. That's it.

Step two — just run something. Anything. The first time you invoke `arctl`, it boots a registry daemon locally, imports a seed catalog of MCP servers, and brings up a web UI on localhost, port one-two-one-two-one. It's all Docker Compose under the hood, so you don't need a Kubernetes cluster just to kick the tires.

Step three — wire up your IDE. Whether you're on Cursor, Claude Desktop, or VS Code, you run `arctl configure` with your tool of choice, and it writes the right MCP config so your IDE talks to the Agent Gateway instead of fifteen separate servers. From that point on, every tool call your AI makes is going through one governed surface.

And the nice thing is — for a real platform rollout, the path is exactly the same. You stand the registry up centrally, you put your operator team in front of curate, govern, and score, and you hand your developers the same `arctl configure` command pointed at your gateway URL.


## Wrap

So that's Agent Registry. If you take one thing away, it's this: it brings the registry-and-gateway pattern you already trust for containers to the AI stack — so your platform team can ship agents to production with the same kind of controls you'd put on any other piece of your software supply chain.

It's open source under Apache 2.0. The repo is `agentregistry-dev/agentregistry`, the site is `aregistry.ai`. Run those three commands, and you'll have a registry up and running in about a minute.


---

# Area 2 — The Drawings

## Intro — drawing cues

- Look at camera, no drawing yet.
- Pause, gesture to the board.


## Panel 1 — drawing cues (the problem)

- Write at top: *Without a registry*.
- Three stick-figure devs on the left, stacked.
- Scatter eight little boxes at random — label them *MCP, Agent, Skill, MCP, Agent, Skill, MCP, MCP*.
- Tangled arrows from every dev to every box — make it messy.
- Tap the mess.
- Four red question marks around the diagram, each with a label: *trust*, *versions*, *governance*, *discovery*.

Reference: Diagram 1 — *Sprawl* (see `agent-registry-lightboard.html`).


## Panel 2 — drawing cues (the fix)

- Move to a fresh section. Write at top: *With Agent Registry*.
- One big rounded box, center of the board. Label it *AGENT REGISTRY*.
- Inside the box, three stacked shelves labeled *MCP servers*, *Agents*, *Skills*.
- Above the box, four pill-words spaced out: *CURATE · GOVERN · SCORE · DEPLOY*.
- Operator stick figure on the left, arrow into the registry, label the arrow *push · curate*.
- Box on the right of the registry, label it *AGENT GATEWAY*. Connect registry to gateway with an arrow labeled *pull*.
- From the gateway, three short arrows up to small boxes labeled *IDE*, *CI*, *runtime*.
- Underline the gateway.

Reference: Diagram 2 — *Registry + Gateway* (see `agent-registry-lightboard.html`).


## Panel 3 — drawing cues (getting started)

- Move to a fresh section. Write at top: *Three commands*.
- Big circled *1* on the left.
- Under the 1, write: `curl … get-arctl | bash`.
- Circled *2* in the middle, with an arrow from 1 to 2.
- Under the 2, write: `arctl mcp list`.
- Circled *3* on the right, with an arrow from 2 to 3.
- Under the 3, write: `arctl configure cursor`.
- Arrow from step 3 down to a box: *IDE → Gateway → curated artifacts*.

Reference: Diagram 3 — *3 commands* (see `agent-registry-lightboard.html`).


## Wrap — drawing cue

- Underline the title *Agent Registry*. Write below it: *Curate · Gateway · Govern*.


---

## Talking-point cheat sheet (off-board)

- What it is: centralized, curated registry for MCP servers, agents, and skills, with an Agent Gateway as the runtime proxy.
- What it solves for platform teams: trust, version pinning, governance and RBAC on AI artifacts, and discovery.
- Mental model: Harbor (registry) + ingress (gateway) + approved base images (curated catalog) — but for agents.
- How it ships: single Go CLI `arctl`, Docker Compose under the hood, web UI on `localhost:12121`.
- Why now: MCP server sprawl in IDEs and CI is the same shape problem containers had in 2014 — same solution shape applies.
- Adjacent projects to name-drop: Model Context Protocol, kagent, Agent Gateway, FastMCP.

Sources:
- https://aregistry.ai/
- https://github.com/agentregistry-dev/agentregistry

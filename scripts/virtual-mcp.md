[Optional cold open — use only if this video might get clipped and shared standalone. Skip if it's running inside the agentgateway series.]

Hey, I'm Sebastian from Solo.io.

[Standard opener — start here if it's part of the series.]

We are now in a world where ai agents are helping developers ship features.. and to do this job, they need to read jira tickets, pull the GitHub issue and the open PR, check the internal architecture docs, and query the team's knowledge base.

For all of these 4 mcp servers being used, we have to manage 4 different connection, 4 different ways they are authenicated and authoizieded ... the way the spec is written today, the agent is on the hook for it all.  


The question I want to answer is: how should the agent actually plug into all those tools — and why does the answer matter more than it sounds like it should.

For every sepearate workflow , each mcp server the agent has its own auth, its own url, its own little catalog of tools for it do anything useful, 

having 4 serves and 4 connections is easy to manage ... looks fine.. until each developer starts spinning up it's own agents, its own mcp servers , 
Four servers, four connections. Looks fine. It isn't.

[Tap the lines]

Every line is its own auth handshake. Its own rate limit. Its own retry. Its own observability story. And every client that wants those tools has to know the full list — the URLs, the credentials, all of it.

But here's the part that really bites.

[Circle the Jira box. Write next to it: 25 tools]
[Circle the GitHub box. Write next to it: 51 tools]

Jira's MCP server exposes twenty-five tools. GitHub's exposes fifty-one. For this workflow, the developer needs maybe two from each. But MCP picks tools at the granularity of the server, not the tool — so the agent gets the full seventy-six dumped into its context, plus everything else from docs and the KB.

[Step back. Wave at the whole right side]

Now the model has to pick the right tool out of a hundred-plus, half of which are noise for this task. Tool selection accuracy drops. Latency goes up. Tokens get burned.

And the knowledge is scattered. Want the Python async docs? The agent has to know the exact URL. Want the runbook? Different URL. None of it is discoverable — it's tribal knowledge baked into prompts.

This is the same N-by-M coupling problem that pushed every REST and gRPC shop toward an API gateway ten years ago. We've seen this movie.


Panel 2 — the fix
[Move to fresh section. Write at top: With virtual MCP]

Same agent.

[Draw agent on left]

But this time, in the middle —

[Draw bigger box in center, label "agentgateway"]

— we put agentgateway. The agent doesn't talk to four MCP servers anymore. It talks to the gateway. One connection. One session. One endpoint —

[Write under the gateway: /mcp]

[Small aside, write off to the side: If MCP is USB for AI… this is the USB hub.]

Now here's where it gets interesting. The gateway isn't just multiplexing connections. It's curating the tool surface.

[Draw the four servers on the right, in a dashed box, label: upstream MCP servers]

Behind the gateway, we still run Jira, GitHub, docs, and the KB. But out front, the gateway publishes a virtual catalog —

[Draw five small tool boxes coming out of the gateway, label them:
  ticket_read
  pr_review
  search_runbooks
  fetch_python_docs
  ask_kb]

Five purpose-built tools. Not seventy-six. Each one is a thin wrapper that the gateway translates into the right upstream call — pinning URLs, injecting API keys from environment, filling in sensible defaults for the parameters the model shouldn't have to think about.

[Draw arrows from the five virtual tools, through the gateway, into the right upstream servers]

The developer doesn't have to remember the Python docs URL. The model doesn't have to choose between fifty-one GitHub tools. The auth keys never enter the LLM context. It's all configuration, sitting in the gateway.

[Mime adding a sixth tool box]

New tool next quarter? Add a few lines of config. No client redeploys. No prompt rewrites. The catalog grows in one place.


Why it matters
[Step back from board. Three short writes:]

[Write: 1. The model sees only what it needs]

Five well-named, well-described tools beats seventy-six generic ones every time. Tool-call accuracy goes up. Token cost goes down. The agent stops guessing.

[Write: 2. Secrets and URLs leave the prompt]

API keys, base URLs, version numbers — all of that gets templated into the gateway config, never injected into the LLM context. One place to rotate keys. One place to bump a docs version. The agent doesn't know and doesn't care.

[Write: 3. Platform teams ship, agent teams consume]

Subject-matter experts curate the virtual MCP for a use case — "developer onboarding," "incident response," "PR review" — and ship it as YAML. Agent teams just point at the gateway. Neither side blocks the other. This is the property that lets MCP actually scale inside a real org.

[Write: 4. Failure stops being the client's problem]

Set failureMode: FailOpen on the backend. One flaky upstream — Jira's down, the docs server is slow — doesn't kill the session. The gateway serves the healthy tools and keeps going. Without this, every agent reimplements that fallback. And they will. Badly.


Land it
[Step to center. One last sentence at the bottom of the board:]

[Write: Virtual MCP = API-gateway pattern, applied to MCP.]

That's the whole idea. Seventy-six tools become five. Four connections become one. Scattered URLs become a curated catalog. The reason API gateways became table stakes for REST and gRPC is exactly the reason virtual MCP matters now — without it, every agent is coupled to the topology of every backend, and that doesn't survive contact with production.

One endpoint. The right tools. Policy in the middle.

That's virtual MCP — and that's what agentgateway gives you out of the box.

[Cap marker. End.]

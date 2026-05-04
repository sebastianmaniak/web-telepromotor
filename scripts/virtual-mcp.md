[Optional cold open — use only if this video might get clipped and shared standalone. Skip if it's running inside the agentgateway series.]

Hey, I'm Sebastian from Solo.io.

[Standard opener — start here if it's part of the series.]

We are now in a world where ai agents are helping developers ship features.. and to do this job, they need to read jira tickets, pull the GitHub issue and the open PR, check the internal architecture docs, and query the team's knowledge base.

For all of these 4 mcp servers being used, we have to manage 4 different connection, 4 different ways they are authenicated and authoizieded ... the way the spec is written today, the agent is on the hook for it all.  


The question I want to answer is: how should the agent actually plug into all those tools — and why does the answer matter more than it sounds like it should.

For every sepearate workflow , each mcp server the agent has its own auth, its own url, its own little catalog of tools for it do anything useful, 

having 4 serves and 4 connections is easy to manage ... looks fine.. until each developer starts spinning up it's own agents, its own mcp servers.. it isn't

because everyone link here has its own auth handshake, Its own rate limit. Its own retry. Its own observability story. And every client that wants those tools has to know the full list — the URLs, the credentials, all of it.

But here's the part that really bites.

[Circle the Jira box. Write next to it: 25 tools]
[Circle the GitHub box. Write next to it: 51 tools]

Jira's MCP server exposes twenty-five tools. GitHub's exposes fifty-one. For this workflow, the developer needs maybe two from each. But MCP picks tools at the granularity of the server, not the tool — so the agent gets the full seventy-six dumped into its context, plus everything else from docs and the Knowledge base..

Now the model has to pick the right tool out of hundred-plus tools, half of which are noise for the task.. 
leading the tool selection accurasy drop, the latecny to gup, the tokens to get burned.. 

And the knowledge is scattered. 
Want the Python async docs? The agent has to know the exact URL. 
Want the runbook? Different URL. None of it is discoverable — it's tribal knowledge baked into prompts.


This is the same N-by-M coupling problem that pushed every REST and gRPC shop toward an API gateway ten years ago. We've seen this movie.

So what do we doo.. lets start a fresh lightboard here...


[ new image ]

Same agent.


But this time, in the middle —

[Draw bigger box in center, label "agentgateway"]

— we put agentgateway. The agent doesn't talk to four MCP servers anymore. It talks to the gateway. One connection. One session. One endpoint —


[Small aside, write off to the side: If MCP is USB for AI… this is the USB hub.]

agentgateway isn't just multiplexing connections. It's curating the tool surface, its really giving the developers a virtual catalog of tools it can use. 

thats the basic story here.. 

The genuinely useful part of agentgateway sitting in the middle... isn't necessarily the same for every caller/ for every agent for every developer. Because the gateway sees the auth on every request, you can scope tool visibility per identity:

"Junior dev agent" → sees ticket_read, pr_review
"SRE agent" → sees search_runbooks, deploy_status, plus a restart_service that nobody else gets

Same gateway same endpoint, same tools/list call, different catalog comes back depending on who's asking. That's where it stops being "just a USB hub" and starts being the actual control plane — RBAC, audit, rate limits, all enforced at the gateway, not begged-for in every agent's prompt.

Why it matters

Five well-named, well-described tools beats seventy-six generic ones every time. Tool-call accuracy goes up. Token cost goes down. The agent stops guessing.


That's the whole idea. Seventy-six tools become five. Four connections become one. Scattered URLs become a curated catalog. The reason API gateways became table stakes for REST and gRPC is exactly the reason virtual MCP matters now — without it, every agent is coupled to the topology of every backend, and that doesn't survive contact with production.

One endpoint. The right tools. Policy in the middle.

That's virtual MCP — and that's what agentgateway gives you out of the box.

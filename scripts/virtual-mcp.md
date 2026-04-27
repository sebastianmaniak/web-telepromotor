Quick one. You've got an AI agent. It needs tools — send email, query a database, fetch a webpage, whatever. Each of those tools lives behind something called an MCP server. The model context protocol — it's how agents talk to tools.

The question I want to answer is: how does the agent actually connect to all of them? And why does the answer matter more than it sounds like it should.


Panel 1 — the problem
[Write at top: Without virtual MCP]

Here's the naive picture.

[Draw agent box on left, label "AI agent"]

The agent. On the right —

[Draw three server boxes stacked: Email, Database, Files]

— the MCP servers. Each one a separate workload. Each one with its own little set of tools.

To get the tools, the agent opens a connection to each server.

[Draw three lines fanning out from agent to each server]

Three servers, three connections.

Looks fine, right? It's not.

[Tap the lines]

Every one of those lines is its own auth handshake. Its own rate limit. Its own retry policy. Its own observability story. And — this is the part that hurts — every client that wants those tools has to know the full list of servers. The IPs, the ports, the auth, all of it.

Ship a fourth MCP server next quarter? You're touching every agent in your org. The topology of your tool fleet is now hardcoded inside every client that ships.

This is the same N-by-M coupling problem that pushed every REST and gRPC shop toward an API gateway ten years ago. We've seen this movie.


Panel 2 — the fix
[Move to fresh section. Write at top: With virtual MCP]

Same agent.

[Draw agent on left]

But this time, in the middle —

[Draw bigger box in center, label "agentgateway"]

— we put agentgateway. The agent doesn't talk to MCP servers anymore. It talks to the gateway. One connection. One session. One endpoint —

[Write under the gateway: /mcp]

Now here's the move. The gateway is configured with a Kubernetes label selector. Something like —

[Draw dashed box on right side, label at top: matchLabels: app: mcp]

Anything in the cluster carrying that label and speaking MCP gets pulled in.

[Draw three servers inside the dashed box]

The gateway federates them. When the agent calls tools/list, it gets back the union — every tool from every server, prefixed by source so they don't collide. email_send, database_query, files_read. One catalog.

[Draw arrows from gateway out to each server]

Drop a fourth server in tomorrow with the right label —

[Mime adding a fourth box inside the dashed selector]

— and clients pick up its tools on their next list call. No redeploy. No config push. No coordination.


Why it matters
[Step back from board. Three short writes:]

[Write: 1. Policy lives in one place]

Auth, rate limiting, per-tool access, traces, metrics — all of it lives in the gateway. The MCP servers themselves stay simple. You don't reimplement production hardening across N servers and N clients. You implement it once.

[Write: 2. Servers add themselves]

Platform teams ship MCP servers. Agent teams ship agents. Neither side blocks the other. This is the property — this right here — that lets MCP actually scale inside a real organization with real numbers of agents and tools.

[Write: 3. Failure stops being the client's problem]

Set failureMode: FailOpen on the backend. One bad MCP server doesn't kill the session — the gateway just serves the healthy ones and keeps going. Without this, every single agent has to reimplement that fallback in its own code. And they will. Badly.


Land it
[Step to center. One last sentence at the bottom of the board:]

[Write: Virtual MCP = API-gateway pattern, applied to MCP.]

That's the whole idea. The reason API gateways became table stakes for REST and gRPC is exactly the reason virtual MCP matters now — without it, every agent is coupled to the topology of every backend, and that doesn't survive contact with production.

One endpoint. Many tools. Policy in the middle.

That's virtual MCP.

[Cap marker. End.]

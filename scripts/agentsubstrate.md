# "What is Agent Substrate?" — Lightboard Video Script
**Target runtime: ~9:00 | Narration: ~1,250 words (≈140 wpm)**

---

## Production notes (read first)

- **Board layout:** Divide the glass mentally into thirds. LEFT = the problem, CENTER = the big idea diagram (this stays up the whole video), RIGHT = architecture details. You erase LEFT once, around 5:30, to make room for the numbers at the end.
- **Pre-draw nothing.** The whole point of lightboard is watching it build. But rehearse the center diagram — it's the money shot.
- **Colors:** Use 3 markers. WHITE/YELLOW for structure, GREEN for "actors/agents," PINK/ORANGE for "workers/hardware." Consistent color-coding does half the teaching.
- **One-liner to memorize** (you'll say it twice): *"Lots of sleeping agents, juggled onto a few warm machines."*

---

## SEGMENT 1 — The Hook & The Problem (0:00 – 1:45)

**DRAW (left third):** A big rectangle labeled "Kubernetes node." Inside it, 6 small boxes (pods). Draw Zzz's over 5 of them. One tiny lightning bolt on the 6th.

**SAY:**

Hi Sebastian Maniak here, and i wanted to give you an overview of what agent substrates is.. 

Here is the life time time line of an agent..

They're lazy.. 

An agent spends almost all of its life doing.. nnothing... It's waiting for a user message, a webhook , a tool results. Then it wakes up, does a few seconds of work and goes back to sleep.

And the standard way we run software at scale is with kubernetes, and in kubernetes... ever one of these agents is a pod.   and a pods that's asleep still costs you money.. Its holding memory, its holding cpu reservation. it takes up a slot on this now. 

and It gets worse.. agents often run unstrusted code -- code the agent itself wrote.. so each one needs its own sandbox. 

Single tenant. not sharing 

So you can't just cram them together. and if we have one thousand, or 1 million agents?  

The kubernets api was never desigend to track a million of tiny, bursy things.. and its schedule takes seconds to place a pod.. which is great for a service that runs for days.. terrifble for a task that runs for 200 milliseconds. 

This is the problem agent substrate existis to solve. \

---

## SEGMENT 2 — The Big Idea (1:45 – 3:30)

**DRAW (center — the money shot):** 
- Top row: ~10 small GREEN circles labeled "Actors" (draw Zzz on most).
- Bottom row: 3 PINK squares labeled "Workers (warm sandboxes)."
- Arrows from a couple of green circles down into the pink squares.
- Big text between them: **"MULTIPLEX"** and the ratio **"250 : 8"**.

**SAY:**

> Agent Substrate — an open-source project out of Google, built on Kubernetes — flips the model. Instead of one pod per agent, it separates two things that Kubernetes normally glues together: the *application* and the *machine it runs on*.
>
> Up here *(green circles)* are your **actors**. That's Substrate's word for an agent-like workload — it doesn't have to literally be an AI agent, just anything with this bursty, mostly-idle personality. You can have thousands of them, millions of them. Most are asleep.
>
> Down here *(pink squares)* are your **workers** — a small pool of pre-started, warm sandbox pods. They're just... sitting there, ready. Empty stages waiting for a performer.
>
> When an actor is idle, Substrate **suspends** it — takes a snapshot of its entire state and frees the worker. When a request comes in for that actor, Substrate **resumes** it into whichever worker is free — in under a second. The actor doesn't know it moved. Its memory, its files, its half-finished thoughts — all exactly where it left them.
>
> So the pitch in one line: *lots of sleeping agents, juggled onto a few warm machines.* Their public demo runs about **250 stateful actors on just 8 pods**. That's 30x oversubscription. Same hardware, thirty times the agents.

---

## SEGMENT 3 — How It Actually Works (3:30 – 6:00)

**DRAW (right third), building top-down as you talk:**
1. A cloud labeled "Request" with an arrow into a box labeled **"atenet (router)"**
2. Box: **"Control plane (ate-api-server)"** with a small cylinder next to it labeled "fast state store"
3. Arrow down to a node box containing **"atelet"** and a worker square
4. A bucket at the bottom labeled **"Snapshots (GCS/S3)"**

**SAY:**

> Let's trace one request through the system. Say a message arrives for agent `my-counter-1`. 
>
> First stop: the **router** *(1)*. Every actor gets its own DNS name, so the router reads the hostname and asks the control plane: "Where is this actor right now?"
>
> The **control plane** *(2)* is the brain — and here's a key design choice: it does *not* store actors as Kubernetes objects. Kubernetes handles the slow-changing stuff — the worker pools, the templates — but the fast-changing stuff, like "which of my million actors is awake and where," lives in a dedicated low-latency store, Redis-style. That's how Substrate stays out of the Kubernetes API server's way and keeps wakeups fast.
>
> If our actor is asleep, the control plane picks a free worker and tells the node-level supervisor — the **atelet** *(3)* — "restore this actor here." The atelet pulls the actor's latest **snapshot** from object storage *(4)* — that snapshot is the full deal: RAM contents *and* filesystem — and restores it into the sandbox. This works because the sandboxes underneath — gVisor, or microVMs — natively support checkpoint and restore.
>
> Actor's awake, router forwards the original request, agent responds. When it goes idle again, the reverse happens: freeze, snapshot to storage, wipe the worker, return it to the pool. The worker is now free for a completely different actor.
>
> And notice what the actor experienced: nothing. From its perspective, no time passed. It might wake up on a different physical machine entirely and never know.

---

## SEGMENT 4 — The Vocabulary + Where kagent Fits (6:00 – 8:00)

**ERASE the left third.** 

**DRAW (left third):** A simple 2-row table:
- "K8s CRDs → **WorkerPool**, **ActorTemplate**"
- "Fast store → **Actor**, **Worker**"
- Below it: "Template → 📸 golden snapshot"

**THEN DRAW (below the table): the layer cake** — three stacked rectangles:
- Top: **kagent** — "build & define agents" (Agent CRD · MCP tools · ADK engine)
- Middle: **Agent Substrate** — "run them at scale"
- Bottom: **Kubernetes** — "provision the metal"
Write the verbs beside each layer: *build → run → provision*.

**SAY:**

> If you open the repo, four terms do most of the work, and they split cleanly into two camps.
>
> The slow, declarative camp — real Kubernetes custom resources: a **WorkerPool** defines your warm capacity — what shape of machine, how many standing by. An **ActorTemplate** defines what an actor *is* — the container image, the memory, the config. From that template, Substrate pre-bakes a **golden snapshot**, so even a brand-new actor's *first* start is just a fast restore, not a cold boot.
>
> The fast camp — living in that low-latency store: **Actor** records tracking "am I running or suspended, and where," and **Worker** records tracking "am I busy or free." These flip states thousands of times a second, which is exactly why they don't belong in the Kubernetes API.
>
> One more thing worth saying: Substrate is deliberately *unopinionated*. It is not an agent framework — it doesn't help you *build* agents at all. So where do the agents come from? That's where **kagent** comes in — and this isn't hypothetical; the integration has shipped.
>
> *(draw the layer cake as you talk)* kagent — kagent.dev, a CNCF project — is a Kubernetes-native framework for building AI agents. Bring your own framework — LangChain, CrewAI, ADK — or define an agent declaratively as a Kubernetes custom resource, or run a full coding-agent harness. Historically all of those deployed as long-running pods. Now, in the kagent UI, you pick your runtime: pod... or **Agent Substrate**. Choose Substrate, and your agent gets scheduled as an actor onto the worker pool — locked down in a gVisor or Firecracker sandbox, snapshotted when idle, resumed in a blink. Same agent, radically cheaper to keep around.
>
> And there's a fun origin story here. The kagent team at Solo.io had already *built* almost exactly this for their enterprise offering — sandboxed actors packed into shared pods, snapshot to storage, resumes as fast as 50 milliseconds. They were about to open-source it when they discovered a team at Google was building the same architecture: Agent Substrate. Two teams independently converging on the same design — that's usually the sign the problem is real. They joined forces instead of competing.
>
> One security bonus worth a mention: with kagent, agent egress runs through **agentgateway** — so your agent calling OpenAI never actually *holds* an API key. Credentials get injected at the edge. Sandboxed compute, governed traffic.
>
> So look at how cleanly this stacks. *(point down the layers)* **kagent** is where you *build* your agents. **Agent Substrate** is where they *run* — densely, sandboxed, suspended when idle. And **Kubernetes** underneath provisions the actual machines. As Christian Posta put it: Kubernetes transformed how we run services — this stack is doing the same for agents.

---

## SEGMENT 5 — Why It Matters + Wrap (8:00 – 9:45)

**DRAW (center, under the main diagram):** Three big numbers:
- **"~100ms"** (activation target, p95)
- **"1,000,000,000"** (actors per cluster, north-star)
- **"30x"** (density, demonstrated)

**SAY:**

> So why should you care? Three numbers.
>
> **100 milliseconds** — that's the north-star activation latency. Wake a sleeping agent fast enough that the user never notices it was asleep.
>
> **One billion** — the target number of actors, active and idle, in a *single* cluster. That's the scale bet: a future where agents are as numerous and cheap as rows in a database, not as expensive as servers.
>
> And **30x** — the density multiplier they've already demonstrated. That's the difference between agents being an infrastructure cost problem and agents being basically free to keep around.
>
> Now, honesty time: this project is *young*. The docs say it plainly — early development, not production-ready, APIs will change. Parts of the architecture are still aspirational. But the core trick — checkpoint-restore multiplexing of sandboxed agents with sub-second wakeups — works today, and you can run the whole thing on your laptop with a kind cluster in about five commands.
>
> *(tap the center diagram)* So next time someone asks what Agent Substrate is: it's not an agent SDK. It's the layer *underneath* — lots of sleeping agents, juggled onto a few warm machines. Build your agents with kagent at kagent.dev, run them on Substrate at github.com/agent-substrate/substrate — and watch your agents learn to sleep for free. Thanks for watching.

---

## Timing budget

| Segment | Content | Time | Cumulative |
|---|---|---|---|
| 1 | Problem: idle agents, heavy pods | 1:45 | 1:45 |
| 2 | Big idea: actors ↔ workers, suspend/resume | 1:45 | 3:30 |
| 3 | Request walkthrough: router → control plane → atelet → snapshot | 2:30 | 6:00 |
| 4 | Vocabulary + kagent (runtime picker, origin story, agentgateway) | 2:00 | 8:00 |
| 5 | Numbers, caveats, CTA | 1:45 | 9:45 |

**Buffer:** ~15s before the 10-minute ceiling — this is now a full house. Pre-marked trims if rehearsal runs long, in order: (1) the agentgateway paragraph in Segment 4 (–20s), (2) the honesty paragraph in Segment 5 (–20s), (3) compress the vocabulary table narration (–15s). Never cut Segment 2, the layer cake, or the origin story — the origin story is the most memorable 25 seconds in the video.

## Things to get right (accuracy checklist)

- Say "agent-**like** workloads" at least once — the project is explicit that actors need not be literal AI agents.
- Don't call it "a Google product" — the repo notes it is *not* an officially supported Google product. "An open-source project out of Google" is accurate.
- Sub-second resume is demonstrated; **100ms is a target**, not a claim. Keep that distinction.
- gVisor **and** microVMs are both supported sandbox types — mention both.
- It runs **on top of** Kubernetes, it doesn't replace it. Kubernetes provisions; Substrate schedules actors.
- kagent facts to keep straight: it's a **CNCF project**, agents are defined as **Kubernetes custom resources** (Agent CRD), it supports BYO frameworks (LangChain, CrewAI, ADK), declarative agents, and coding-agent harnesses, and it ships MCP tools for K8s, Istio, Helm, Argo, Prometheus, Grafana, and Cilium.
- The kagent ↔ Substrate integration is **shipped and public** (Christian Posta's Solo.io blog, June 2026; kagent chart v0.9.7+). Accurate claims: kagent's UI offers *Runtime → Agent Substrate* alongside the classic 1:1 agent-per-pod mode; agents scheduled to Substrate run as actors in gVisor or Firecracker sandboxes; egress routes through agentgateway with credentials injected at the edge.
- Origin-story numbers: the **50ms / 200ms** resume figures belong to Solo's *pre-merge custom solution* (Bubblewrap and Firecracker respectively) — don't attribute them to Agent Substrate itself. Substrate's own claims stay "sub-second demonstrated, 100ms target."

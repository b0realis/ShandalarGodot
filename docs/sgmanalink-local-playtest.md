# SGManalink LAN playtest

Development source: `main`, version **0.40.18**. A desktop LAN full-pool duel
milestone, not the public Internet release. No Nakama, account service, central
directory or MElo is required. Offline duels, hotseat, demonstration and Deck
Builder retain their existing code paths.

The **Tournament** tab adds [LAN knockout events](sgmanalink-tournaments.md)
with 2–20 entrants, a separate or participating organiser, first to 1/2/3 wins,
fixed/approved/own deck policies, a live Master Panel, an advancement diagram
and final standings. [Computer opponents](sgmanalink-computer-players.md) can fill
duel rooms and a chosen number of tournament seats. Protocol **21** and the
current rules fingerprint require matching updated builds and enabled card
catalogues on every computer; old LAN development builds cannot join.
Internet play and MElo are parked.

The [gameplay review](sgmanalink-gameplay-parity-2026-09-15.md) records the match
introduction and manual checks. The [pack integration](packs-sgmanalink-integration.md)
and [follow-up bug campaign](integration-bug-campaign-2026-09-16.md) record the
current pack support, compatibility rules and payment regressions.

For repeatable automated network play, see the
[network campaign](sgmanalink-network-campaign.md). It runs two fair-information
coverage pilots over real TLS, including duplicate commands and reconnects.
The offline AI-versus-AI demo by itself does not test LAN networking.

## Two computers on the same network

Use matching **0.40.18 development builds** and enabled packs on both computers. The older
0.20.0 release does not contain this LAN milestone.

1. Open the main-menu globe on both computers. In **Identity**, enter a name
   or **Generate name**, optionally tick **Remember this name on this device**,
   then **Use this identity**. Names use up to 20 letters, numbers, spaces,
   - or _. This is a temporary display name, not a verified or reserved account.
   You can skip identity creation and play as a guest.
2. On the host, open **Host Game** and name the duel. Under **DECKS** keep
   **Bring your own deck**, or choose **Assigned deck** and **Choose deck…**
   to pick the one list both seats will play. Under **ACCESS** the table is
   **open** by default: anyone on your network sees it in their Game Browser
   and joins with a click, no invitation needed. Switch on **Invitation
   only** if only the players you send the invitation to may join; **Copy
   invitation** sits right beside the switch. Choose **Host on LAN**; the
   host connects itself and creates the duel room automatically.
   **Network settings…** holds the LAN IPv4 address (usually `192.168.`,
   `10.` or `172.16.` through `172.31.`; with several adapters, choose the
   address on your opponent's network), the port, the **Listed in the LAN
   game browser** switch and same-computer testing; **Table rules…** shows
   what the table plays.
3. On the other computer, open **Game Browser**, then **Find LAN games**.
   Every duel on the network is listed by name with its host, deck rule
   (**Bring your own** or **Assigned: …**), an **INVITE ONLY** tick and
   build. Choose **Join** beside the duel: an open table connects and seats
   you at once; a ticked table opens the window to paste the invitation.
4. For an invitation-only table, the host chooses **Copy invitation** (on
   Host Game or in the duel room) and sends it privately. It is a long,
   single-line `sglan1:` invitation: host address, port, public certificate
   and a temporary access secret. Copy the whole thing. The guest chooses
   **Join** beside the duel, or **Join by invitation…**, pastes it and
   chooses **Connect**; no discovery or manual IP/port entry is needed.
5. In the connected browser, choose **Join** beside the host's duel if you
   are not seated yet. At a bring-your-own table use **Choose / review deck**
   to search shipped and locally saved decks, inspect the complete list,
   then **Use this deck**. The chooser stays open until the host confirms
   the selection; a refusal keeps the selection and shows an explanation.
   At an assigned-deck table both seats already hold the host's deck;
   **Review assigned deck** shows its full list and no other deck is
   accepted. Both choose **Ready**.
   Changing either deck or replacing an opponent clears both Ready flags so
   both players can review again. Reconnecting the same seat preserves readiness.
6. The duel room's header names the table's access: an open table reminds
   the host that players see it in their Game Browser; an invitation-only
   table keeps **Copy invitation** beside that line.
7. Review the **online match introduction**: both player/deck names, the actual
   room rules, **Unrated** and **No ante**. Choose **Continue** when ready;
   this appears once before the duel, not every turn. The information stays
   beside your opening hand while you decide whether to keep or redraw.
   Play on the **same duel screen as an offline duel**. The coin-toss winner
   chooses Play first or Draw first; keep or redraw when prompted. Click a hand
   card, choose any mode/X, then click its targets on the table, portraits, spell
   chain or public pile. If mana is needed, tap sources without cancelling the
   selected spell. Double-click auto-pays; individual mana sources remain your choice.
   Use Done, phase stops and the normal shortcuts to advance. Select attackers by
   clicking them; click a blocker then an attacker to block. Confirm with Done.
   Divide damage with the existing click-per-point combat controls and choose
   cleanup discards in your hand.

Overview explains prerequisites, hosting versus joining and the Ready flow;
it does not repeat the navigation buttons. Use the top tabs for Identity,
Host Game and Game Browser.
The waiting room shows both player names, deck titles and readiness side by side.
Long pages scroll inside the window, leaving connection notices visible.
**Escape** or **Back** in the deck chooser returns only to the room. Changing
the search clears any previously selected result. The chooser closes if its
room ends or the duel begins. Your identity is fixed while connecting or during
a visit; use **Overview -> Disconnect** to end or cancel that visit before
choosing another name.

Auto-payment pauses for a mana source's colour/cost question and resumes after
your answer. Automatic X respects **Don't auto tap** marks, coloured X costs,
cost modifiers and target-count charges. You can still select X and tap manually.
Repeated additional costs, such as Taste of Paradise, have an explicit payment
count. Life-X, such as Fire Covenant, starts at zero and must be chosen manually;
double-click never chooses a life payment for you.

Pack enabling/disabling and rescanning are locked while hosting, connected or
waiting to reconnect. Close/forget connections and stop hosting before changing
the catalogue. A deck needing a disabled pack explains this lock; it can still
be loaded as proxies. Deck Builder's cosmetic source filters remain available.

The normal **L** duel log now shows a filtered online history. It records public
actions and information your seat was allowed to see, including private looks;
it never copies the host's raw log or duel seed. Reconnect catch-up retains the
last 256 entries per seat on the host; if older entries are unavailable, the log
says so. Received history stays in the current client window and may be saved
with its Save button. Previously public observations remain history even if a
card later becomes hidden; they are not live access to that hidden card.

The host must keep its lobby and application open for the whole duel.
Closing that host stops its service and all rooms. There is no account
setup, router configuration, automatic port forwarding or external service.

An open table publishes its invitation in its LAN listing on purpose: anyone
on the network who can see the listing may join, which is what a kitchen-table
LAN wants. An invitation-only table's listing carries the duel's name, deck rule
and certificate fingerprint but never the secret or the certificate; its
invitation is a secret. Clipboard managers and the application used to send it
may keep their own history. The game does not store invitations, private keys
or seat credentials in settings or logs. Only a display name is saved, and only after explicit confirmation with
**Remember** checked. Cancel discards both name and remember-choice edits; using a name with
Remember unchecked removes the saved preference. Stopping the host invalidates its invitations; starting
again generates new credentials. Names are not globally reserved.

## What can be played

All shipped and locally saved decks whose cards are implemented can be selected.
The host accepts names from the complete registered card pool, not scripts,
resources or paths from another computer. Main decks contain **40–250 cards**;
sideboards may contain up to 250 and can be reviewed but are not used in this
single-duel format. Build and save a custom list in the existing Deck Builder
before opening SGManalink. No selection leaves the explicitly named 40-card
Forest practice deck as a fallback, not a card-pool restriction.

Room rules currently use **Unrestricted**, 20 starting life, mana burn on and
free combat-damage assignment. The referee flips the coin; its winner chooses
whether to play or draw first.
There is no between-games sideboarding, match series or ante in this milestone.

That paragraph describes an ordinary duel room. Tournament pairings support
multi-game series but retain locked decks, no sideboarding and no ante.

Online play subclasses the existing `DuelScreen`, rather than maintaining a
second approximation. The same battlefield layout, full-size preview, draggable
hand, portraits, phase/combat bars, Combat window, spell chain, target arrows,
damage markers, spell flights, card sounds and music are used. Your seat always
appears below your opponent's. Hand style, placement and other presentation
preferences are shared with offline duels.

Territory colours use the same deck-based palette as local setup. This is a
single public cosmetic value fixed when the duel starts, not an opposing deck
list or a colour inferred from hidden draws. The Online control uses the duel's
stone button style. Sending, reconnecting and suspended states appear there;
they do not overwrite combat, targeting or phase instructions. Open connection
details update in place. Opening-hand buttons stay stable across network updates,
and the normal defeat countdown uses the previous displayed life total.
Restoring a duel already in combat also refits its window after layout or resize,
keeping the title clear of the large-card sidebar without rebuilding its cards.

Spells and live abilities use the referee's legal targets, modes, X and divided
damage. The original choice window handles private searches and cost/resolution
questions, including information revealed before the question. The **Online**
button in the strip below the large card offers connection controls, recent
revealed information and special actions such as Channel payments. The referee
validates every answer. Menus stop your local automatic passing, not the other
player; disconnects suspend game actions. Closing SGManalink requires confirmation.

Opponent hands are normally counts. A card rule may explicitly reveal cards or
permit a private look; only the authorized viewer receives that information.
**Revealed information** retains recent looks as past observations, not live
access to hidden zones. Revelation and Field of Dreams expose only the zones
their rules permit, while active. Render cards are detached
local presentation objects, not host engine instances. Card art and skins stay
local; no asset transfer occurs. The renderer receives a detached projection,
not the host's game or a hidden-state snapshot. Durable replay and the wider
offline match/room/rules options remain separate work. Registry-wide rendering and
representative mechanic tests are not an exhaustive online playtest of every card.

## Discovery and firewall help

- Search sends local IPv4 UDP broadcast queries to **17898** every two
  seconds. Each host replies directly to the querying computer; there is
  no shared directory. Listings expire after seven seconds without replies.
- Listings contain a temporary host name, address, game port, public
  certificate fingerprint, open-room count and, when present, tournament name.
  They contain no invitations,
  access/resume secrets, private keys, hands or decks. Discovery is not an
  identity guarantee; the separately shared invitation pins the TLS host.
- Default gameplay port: **TCP 17897**, or the port selected by the host.
  Allow the game on both computers' **private/local network** when the operating
  system asks. Do not disable the firewall or open router/Internet ports.
- If discovery is empty, try the invitation directly. Broadcasts may be
  blocked on guest Wi-Fi, separated subnets, VPNs or networks with client
  isolation. Client isolation may block direct play too.
  With several adapters, discovery depends on the operating system's LAN
  route; a direct invitation still targets the host's selected address.
- A busy UDP 17898 port disables that host's advertising, not its game
  listener; the UI reports this and direct invitations still work. Only
  one advertising service per computer is supported in this milestone.
- If a selected discovery result does not match an invitation's address,
  port and certificate fingerprint, joining is refused. **Clear selection**
  to deliberately join the pasted invitation instead. If the host restarted,
  request its new invitation.
- Use a currently assigned private IPv4 address. IPv6, public IPs,
  hostnames/DNS and Internet NAT traversal are outside this milestone.
  Private-address checks are a scope restriction, not a substitute for a
  firewall: do not expose this service with a reverse proxy or forwarding.

## Platforms

The LAN implementation uses native Godot networking APIs for Windows,
Linux and macOS. Its temporary TLS trust certificate cannot be installed
into a browser through Godot, and browsers cannot send LAN UDP broadcasts
or start this TCP listener. **This LAN milestone is desktop-only.** Web
offline play remains unchanged; future web multiplayer needs a separately
reviewed transport, such as WebRTC with signaling and relay support.

Exporting a platform is not proof of runtime compatibility. Dated test and
build results are in the roadmap. Two different physical computers remain
an important playtest even after automated local-socket tests pass.

## Same-computer fallback

For an isolated two-window check, **Host Game -> Same-computer testing ->
Start local service** retains the original loopback path. Use **Host a duel**
to create its room. Copy its access code and port into the other window's
**Game Browser -> Same-computer testing**, using the **Local test port**, and Connect.
This path uses plain `ws://` only on `127.0.0.1`, does
not advertise and cannot connect to another computer. LAN invitations
always use encrypted `wss://`; they never fall back to plain WebSocket.

## Session and security boundaries

- Hosting/scanning happen only on explicit button clicks. Opening the globe
  does not start a listener or send discovery packets. Closing stops sockets.
- A host generates an ephemeral RSA-2048 key and self-signed certificate.
  The client trusts only the certificate carried in the privately shared
  invitation, with an explicit common-name check. No unsafe TLS mode or
  operating-system trust-store changes are used. The `.invalid` common name
  is a local certificate label, not a domain to resolve or purchase.
- A Godot 4.7.2 certificate string-export defect is worked around using an
  automatically removed temporary file containing **only the public
  certificate**. Private keys and access/resume secrets never go to disk.
- The invitation grants a new guest session. A separate random resume
  capability controls the seat. Knowing/reusing a nickname cannot reclaim
  another session. Duplicate names get distinct service-local guest numbers.
- Disconnects pause game actions until both seats reconnect; concession is
  still available. Retry restores the same seat and does not execute a
  command twice. Replacing the controlling connection displaces the old one.
- A submitted action remains pending until both its acknowledgement and a
  following room snapshot arrive. If it has not completed after 15 seconds
  on an established connection, the client reconnects and retries the same
  sequence; an already-applied action is not executed again. This deadline
  concerns a pending command, not the time a player takes to decide a move.
- A disconnected room seat is held for **five minutes**. On expiry it is
  released; an unfinished duel is conceded by the expired seat. Roomless
  disconnected guests expire after 30 seconds and may be reclaimed sooner
  when capacity is needed. Before the duel starts, the room host can choose
  **Remove disconnected guest**. Connected guests cannot be removed this way.
  Tournament entrants are an exception: their entries are reserved, not
  automatically forfeited. The organiser explicitly withdraws absent entrants;
  the separate recovery code can reclaim an entry after closing the application.
- Closing the client lobby forgets its seat; it cannot be recovered by
  reopening. Departure requests release it immediately; if the request cannot
  reach the host, the disconnect grace applies. Concede before intentionally
  leaving a running match. Host shutdown loses all room/session state;
  there is no durable live-duel journal. Tournament pairings and completed game
  scores have private checkpoints; interrupted games restart, not resume.
- Limits: twenty-four connections (twenty entrants, organiser and reconnect headroom),
  forty-eight guest sessions, ten rooms per host;
  bounded JSON nesting, arrays, bytes, command queues and acknowledgements;
  32 KiB commands, 2 MiB views and a 512-card limit per transmitted collection
  (legal-block adjacency is bounded separately by rows and columns);
  handshake deadline and message rate limits. Discovery has a 64-host cache,
  768-byte packet ceiling and at most sixteen replies per second per host.
  An oversized command is rejected locally with an explanation before it
  consumes a sequence or enters the retry queue; limits apply after encoding.
- Server commands and host-to-client DTOs are validated before use. No
  arbitrary object deserialization, script/resource loading or remote method
  dispatch. Duplicate/contradictory card locations, absent combat-card references
  and unknown keyword values are rejected before replacing the client view.
  Seat authorization comes from the connection, not a player
  number submitted by the client. The data protocol is version 22 (all players
  need this updated build, including the table's deck rule and assigned deck,
  the open host's published invitation, viewer-specific exile-play permissions,
  public hack-effect reminders, live ability badges, the protection-from-
  artifacts badge, each face's printed power/toughness, the turn's
  extra-block permission, the organiser's pause/resume and ruling words,
  the tournament table's `hold` reason, each seat's land-drop allowance
  beside its counter, the public half of a damage division — its amount
  and targets — for the watching seat, the creatures an open regeneration
  window is about, public active player-protection descriptions, and no printed cost on a face — the client prices a
  named card off its own registry);
  the invitation keeps the `sglan1:` envelope prefix and carries the same
  protocol-22 compatibility check inside it. A handshake fingerprint additionally
  checks the release version, maintained rules revision and printed card catalogue,
  and a readable stamp `{game, rules, packs}` travels beside it in the hello and
  in every LAN advert, so a refusal — and the game browser's BUILD column — can
  say which of the three differs instead of "incompatible build".
  It detects incompatible builds, not modified-client cheating or player identity.
  Enable the same gameplay packs before connecting. Hosting, connecting and
  resumable sessions lock pack changes/rescans until Stop/Forget; ordinary Deck
  Builder source filters do not change the active catalogue. A new connection
  fingerprints the current pool, including enabled packs. See the
  [integration audit](packs-sgmanalink-integration.md).
  Invalid invitations, expired seats, incompatible builds and full hosts report
  distinct failures and do not trigger endless automatic retries.
- Each client receives a detached allowlisted view. Opponent hands and library
  order are not transmitted unless a card rule expressly permits that look/reveal.
  Engine logs, RNG state and raw engine IDs are never transmitted. Deck lists
  are sent to the referee and their owner, not the other client; deck titles
  are public. Hidden-zone searches use sorted names, not library order.
  Handles survive public moves so the shared card animations retain continuity;
  they are retired when a card becomes hidden to a seat, or an opening hand is shuffled.
  A creature remains marked as blocking when its attacker leaves combat, but
  that historical block does not create a handle for a hidden or vanished card.

The player operating the host can inspect its full rules-engine state or
modify the executable. Transport encryption and filtered client views do
not make that host an impartial referee. This milestone is **unrated
friendly play**; it does not claim cheat-proof multiplayer. The existing
engine RNG is unchanged, not a cryptographic ranked-shuffle protocol.

## Verification and next work

`./run_tests.sh -gselect=test_sgmanalink` covers exact schemas, guest labels,
private-state substitution, host/join/ready, encrypted invitation connections,
seat resumption, UDP query/reply and expiry, hostile host DTOs, stale/duplicate
commands and a complete encrypted duel through the interface controls, driven
only from client views. Interface tests cover identity persistence/cancel,
small-window layout, deck lists, hidden-card rendering, targeting, private choices
and combat/damage input. Full-pool tests round-trip every registered definition
through the view schema and detached renderer. Focused mechanic cases exercise
auras, modal/X spells, counterspells, regeneration, divided damage, sacrifice costs,
searches, private/public reveals, masked cards and special payments. Encrypted
deck-submission tests check privacy, validation, readiness resets and reconnects.

The stabilization regressions include 24-by-24 combats, reserved-mana X,
colour-choice cancellation and lost-ack recovery, journal privacy/deduplication,
session churn/expiry, and compatibility failures. Searches, triggered payments
and split combat damage also survive interrupted connections and lost answers.
After reconnecting, input stays disabled until the fresh room snapshot arrives;
a welcome alone must not enable commands against a stale room revision.
The second robustness pass also holds back acknowledgements' following snapshots,
recovers a stalled result without repeating the action, rejects malformed views
over a real socket, checks fresh readiness after an opponent changes, and keeps
returned/shuffled attackers private while preserving the remaining blocker's status.
The varied-deck socket soak
alternates shipped decks and reuses sessions across rematches, with delayed
processing, duplicate commands and repeated reconnects. For a longer run:

```sh
SGMANALINK_SOAK_ROUNDS=4 ./run_tests.sh -gselect=test_sgmanalink_network.gd -gunit_test_name=test_varied_deck_rematches_with_latency_disconnects_and_duplicate_commands
```

Rounds are bounded to 2–20; each duel also has a command ceiling and each
network wait a frame budget. These tests do not replace physical LAN playtests.

## Two processes on this computer

Every test above builds its host and its guest inside one process. For a
rehearsal of the two-computer flow with a second copy of the game,
`tools/lan_smoke.sh` starts **two** Godot processes with separate data
homes, hosts on this computer's own private IPv4 address and plays one
whole duel between them over `wss://`: the advert, the `sglan1:`
invitation, the pinned certificate, both deck choices, the coin toss, a
mulligan, a mid-duel disconnect and resume, and the host closing the table.

```sh
./tools/lan_smoke.sh --seed 4250 --keep
```

It prints the connect time, every action's round trip and the largest
message each side sent, and it fails on any error line or on a run that
never reached its verdict. Measured on one Linux laptop, 2026-09-17:
connect 19–34 ms, 205 actions a seat at a 17–24 ms median round trip, a
whole fifteen-turn duel in 11.6 s, largest command 926 bytes, largest room
snapshot 56 KiB against the 2 MiB view limit.

One thing it cannot prove: **a computer does not receive its own LAN
broadcast**, so `Find LAN games` still needs the second computer. When the
sweep is silent the smoke asks the host's address directly, which
exercises the same query, reply, advert contents and fingerprint match.
Two different physical computers remain the playtest this stands in for.

Implementation notes: `SgCompatibility.RULES_REVISION` must change for engine
or card-behaviour changes between release versions. The current optimized
encoder retains ASCII escaping and the original parser limits. View construction
is memoized per room revision and seat; publications are coalesced, including
duplicate-command replies, and unrelated duels are not rebuilt for another room's
command or a roomless visitor's departure. X-budget estimates share one
source enumeration within each view and use a bounded search against actual
engine payment costs.

See the [second-pass record](sgmanalink-hardening-2026-09-14.md) for its
reproductions, recovery checks and verification results.
The [visual parity review](sgmanalink-visual-parity-2026-09-15.md) records the
matched native-rendering checks and subsequent presentation corrections.

Next: two-computer full-deck and tournament playtests. Internet invitations,
public discovery, account providers and MElo are parked; none is required for
LAN play. See [the tournament guide](sgmanalink-tournaments.md),
[the design](sgmanalink-design.md), the
[authentication options](sgmanalink-authentication.md) and
[block-MElo exploration](block-MElo.md).

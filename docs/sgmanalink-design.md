# SGManalink: LAN duels and tournaments

**Current decision, 2026-09-15:** focus this repository's multiplayer work on
desktop LAN play and [local tournaments](sgmanalink-tournaments.md).
Internet hosting/discovery, permanent identities and MElo are parked for lack
of resources. The account and public-service proposals below are retained as
design history, not a dependency or an implementation commitment.

Status: design and staged implementation, 2026-09-14 (developed on a
`sgmanalink` branch from `5b0b037`, since merged into `main`). The first
[LAN practice implementation](sgmanalink-local-playtest.md) now
exercises decentralized desktop LAN host/discover/join and a host-refereed duel. Public online
service, permanent personas, durable matches and player MElo remain
unimplemented. **Current scope: player-hosted games, temporary names, no
central authentication or ranking.** Account/MElo proposals below are parked
future options, not prerequisites for guest hosting.

For now, continue the game experience with temporary guest nicknames, not
permanent name reservations. The [authentication and hosting note](sgmanalink-authentication.md)
records backend requirements, dated free-tier candidates and decentralized
alternatives; no official domain or provider has been selected. LAN search
uses bounded UDP broadcasts and private replies, not a central directory.
Native clients join with an invitation that pins an ephemeral TLS
certificate: an open table (the default) publishes it in its LAN listing so
the Game Browser joins with a click; an invitation-only table hands it out
privately. Public Internet discovery, NAT traversal and web multiplayer
are separate future work, not supplied by local broadcast discovery.

The goal is dependable online duels behind the familiar Shandalar stone,
scrolls, portraits and globe. Keep Windows, Linux, macOS and web clients;
offline duels, hotseat and the Deck Builder must remain usable without an
account or a network connection. Start with browse/host/join duels; leave
booster drafting and complete tournaments for later milestones. (LAN
knockout tournaments and an offline Booster Draft have since been
implemented.)

## Three separate responsibilities

1. **Identity:** prove control of a particular player account.
2. **Connection:** authenticate requests and protect them in transit.
3. **Match integrity:** enforce the rules and record a trustworthy outcome.

A key proves account control, not one human per account, honest match
results or an uncompromised computer. Plan for modified clients, stolen
sessions, lookalike names, replayed messages, malformed input, dishonest
hosts, collusion and ordinary network/server failures. Neither TLS nor
cryptography eliminates smurfing, external advice or the need for moderation.

## Personas: stable identity, replaceable credentials

Recommended account model:

- A server-generated, opaque, permanent `PlayerID` owns match history and
  MElo. It is not a nickname, email address or public-key fingerprint.
- A unique, normalized public handle identifies the persona in the lobby.
  Initially use a conservative ASCII handle alphabet; optional display
  names can be richer but must not replace the canonical identity.
- Show the handle and a stable profile link/account discriminator in
  invitations and match details. A copied portrait or similar-looking
  display name does not become the same player. Handle changes must not
  silently transfer the old identity or its rating to another account.
- Bind multiple passkey credentials to one `PlayerID`; key replacement
  must not reset the player's history. No legal name or public email is
  required. Pseudonymity does not hide connection metadata from the service.

Use WebAuthn/passkeys through a maintained authentication component. A
server challenge is signed by an authenticator and checked against the
registered public credential and expected relying party/origin. Require
user verification, challenge expiry and single use. The server holds no
passkey private key; authenticator/provider storage and syncing depend on
the passkey type. This is the useful public/private-key idea behind the SSH
suggestion, with web-facing origin binding.
[WebAuthn specification](https://www.w3.org/TR/webauthn-2/).

Do not ask players to import their GitHub or administrative SSH key. Raw
SSH keys would add browser, storage and recovery friction and invite a
custom authentication protocol. A separate game-only signing credential
could be considered later, but is not the default sign-in design.

For desktop, use the system browser for sign-in and a maintained
OAuth/OIDC flow with Authorization Code + PKCE, registered redirects and
state validation. Native clients are public clients, not holders of a
compiled-in client secret. Browser clients sign in on the official HTTPS
origin. Validate the Linux/browser/device combinations before choosing an
auth component. [Native-app OAuth guidance](https://www.rfc-editor.org/rfc/rfc8252.html).

Choose a durable official domain and WebAuthn relying-party ID **before**
enrolling real players. Protect domain, deployment and administrator
accounts as part of the identity system. Arbitrary community servers must
not receive official-account credentials or reusable official tokens.

### Recovery is part of the first account release

- Encourage a second passkey/security key and offline, single-use recovery
  codes. Generate codes securely, store only verification hashes, throttle
  attempts and invalidate a code on use.
- Require recent strong authentication or the reviewed recovery flow to
  add/remove credentials. Let players inspect and revoke active sessions
  and lost devices; apply appropriate recovery notifications and safeguards.
- Never let someone reclaim a persona by merely knowing its nickname or
  convincing support to bypass proof. If all credentials and recovery
  methods are lost, safe recovery may be impossible; explain that upfront.

These are proposed controls informed by
[NIST account-recovery guidance](https://pages.nist.gov/800-63-4/sp800-63b.html),
not a claim of certification. A private recovery contact, if offered,
needs its own privacy and takeover-risk review.

## Transport: HTTPS and secure WebSockets

Recommend HTTPS for account/lobby requests and WSS for live duel messages.
Godot supports WebSockets in both native and web exports, and the protocol
fits turn-based play. Reliable ordered delivery applies to a live
connection; it does not make an interrupted match durable or a retried
command execute only once.
[Godot WebSocket documentation](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).

The public endpoint needs TLS, authenticated/revocable sessions, strict
browser Origin validation, CSRF protection, per-message authorization,
payload limits, throttling and backpressure. Exclude credentials and
private payloads from routine logs. These are baseline requirements, not
features automatically supplied by WebSockets.
[OWASP WebSocket guidance](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html).

Protocol requirements for this project:

- Use small, versioned, typed messages with explicit allowed fields and
  actions. Reject unknown actions and oversized/deep structures before
  engine dispatch. Never deserialize arbitrary Godot Objects, Callables,
  resource paths or scripts, or expose arbitrary methods as remote calls.
- Resolve the player's match seat from the authenticated session, never
  from a submitted player number. Check authority for every action and
  pending choice, including after a reconnect or session revocation.
- Check protocol, rules and card-catalogue versions before a match starts.
  Deck registration accepts validated card identifiers/counts, not code or
  uploaded resources. Bound deck sizes and all processing work.
- Include a unique command ID and expected match revision. Reject stale
  commands; retries with the same ID return the recorded result, not a
  second cast, payment or rating change. A reused ID with a different
  payload is an error.
- Serialize decisions through one active writer per match. Persist
  accepted decisions, deduplication data and random outcomes before
  acknowledging them. Define replay/checkpoint recovery and writer fencing
  before claiming crash-safe delivery; an in-memory cache is insufficient.
- Heartbeats, bounded queues and reconnect backoff handle failures.
  Reconnection authenticates the same seat and returns only its permitted
  view. Decide how a new connection replaces an old one to avoid two
  competing controllers.
- Define grace periods, match clocks and server-outage handling explicitly.
  A brief dropped connection must not automatically become a defeat.
- Browser Origin is a browser security check, not proof of identity.
  Native-client handshakes need an explicit authentication policy, not a
  wildcard exception that weakens the browser endpoint.
- Keep bearer credentials out of URLs and game configuration files. Prefer
  secure browser sessions and OS-protected desktop credential storage;
  specify token renewal, expiry and revocation before public sign-in.

## Authority: the server plays referee

For MElo matches, a trusted neutral server runs the existing headless
`MtgGame` rules engine. Clients submit intentions; the server checks
priority, legality, costs, targets and choices, owns randomness, and
determines victory. The client renders an allowed view rather than owning
an authoritative copy of the complete game.

Each seat receives only what that player is entitled to know. Never send
the opponent's hidden hand, unknown library order, future random outcomes
or full RNG state/seed and merely hide them visually. Apply this to
snapshots, events, logs, errors, choice lists, debug endpoints and replays.
Handle rule-authorized reveals explicitly. Registered decklist visibility
is a format policy, not permission to disclose current library order.
Avoid stable hidden-card identifiers that allow tracking through shuffles.

Spectators require their own filtered view and anti-ghosting policy;
disable ranked spectating initially unless a safe policy is implemented.
Public replay publication must not accidentally expose private decklists
or account metadata. The existing fair AI information contract remains
unchanged; the optional Unfair challenge stays outside ranked play.

### Existing-code boundaries that must be changed deliberately

- [`duel_screen.gd`](../game/duel/duel_screen.gd) directly reads
  `game.players`, including libraries. Add view/command adapters while
  preserving the local mode; do not network this object graph unchanged.
- [`GameSnapshot`](../engine/game_snapshot.gd) is an in-memory rewind
  mechanism holding live object references and RNG state, not a safe wire
  format or durable match save. Network views and recovery records need
  explicit schemas. The AI observation object is also not automatically a
  complete network projection.
- [`DuelLogFile.banner`](../game/duel/duel_log_file.gd) includes the seed
  for useful local debugging. Online client logs must not inherit that
  banner or unrestricted engine log content.
- [`MtgGame`](../engine/mtg_game.gd) uses `RandomNumberGenerator`; Godot
  distinguishes this ordinary PRNG from cryptographically secure
  randomness. Keep deterministic offline/test behavior, but audit every
  random call and introduce a reviewed server-only secure randomness
  boundary before ranked play. A secret seed alone is not the full design.
  [Godot randomness guidance](https://docs.godotengine.org/en/stable/tutorials/math/random_number_generation.html#cryptographically-secure-pseudorandom-number-generation).

Ranked randomness must be unpredictable to players, use unbiased sampling
and survive the engine's preflight/rewind behavior without changing real
outcomes. Design private recorded outcomes/checkpoints and recovery before
implementation; do not roll custom cryptography or simply replace the RNG
without accounting for probes. Secret replay data stays server-side with
limited retention/access. These are online requirements, not evidence of
a newly discovered offline gameplay bug.

## MElo: player results, not client claims

- Attach ratings to `PlayerID` and results to a unique `MatchID`. Record
  the two participants, approved format/rules/engine version and outcome.
  The existing DeckLab deck Elo ledger is separate from player MElo.
- Accept outcomes only from trusted match workers. A client saying or
  signing "I won" is not evidence that the game was legal.
- Finalize each match and its rating effects transactionally and
  idempotently. Retries, worker restarts and duplicate events must not award
  a second win. Keep an auditable correction path with a rating-policy
  version; administrators should not silently rewrite the ladder.
- Start with one clearly defined rated queue. Private/self-hosted games,
  guests, custom rules and AI/Unfair matches are unrated by default. A
  player hosting a room on the trusted service is distinct from operating
  their own server; the former can still use a neutral referee.
- A self-host operator can inspect hidden game state or fabricate results.
  Signing their result does not fix that. Supporting community servers does
  not mean accepting them into the official MElo trust boundary.
- Introduce provisional ratings and review repeated-opponent farming,
  collusion and suspicious result patterns. Account keys do not prevent
  multiple accounts. Do not treat a shared household IP as proof of abuse.

Choose the rating formula, uncertainty/provisional policy, matchmaking,
inactivity/seasons and appeals rules separately, and publish them before
ranked launch. The promise is accountable fair play, not an uncheatable or
one-human-one-account system. Players necessarily trust the ranked service
operator; encryption does not conceal server state from its administrators.

## Small backend, familiar frontend

Begin with one managed deployment: a TLS edge, a maintained account/lobby
component, isolated headless match workers and a transactional database.
These are responsibility boundaries, not a demand for many microservices.
Workers should have only narrowly scoped match/result permissions, no
administrator or identity-store secrets. Keep authentication separate
from card scripts and from the pure rules engine.

Use dependency updates, restricted admin access, resource/process limits,
minimal sensitive logging, monitored failures and tested backup restoration.
Before public hosting, define deletion/retention, account recovery support,
moderation and incident response. Defer free-form public chat and arbitrary
uploads rather than adding those abuse surfaces to the first duel service.
No blockchain, custom crypto or peer-to-peer ranked lockstep is needed.

[block-MElo](block-MElo.md) explores optional community-verifiable ledgers,
federation and blockchain alternatives. It is a discussion document, not
a replacement for this baseline or a selected implementation.

The proposed future account-backed lobby would offer **Create persona / Sign in**,
**Browse / Host / Join**, portrait, canonical handle, connection indicator
and an unambiguous **Casual / MElo** label. Browser authentication can be
modern while the in-game presentation remains old-school. Clearly show
whose turn it is, reconnection status and whether a result affects MElo.

## Milestones and acceptance gates

1. **Local referee prototype (implemented):** two clients through explicit
   commands and seat-filtered views; no public accounts or rating. Tests
   must cover illegal/out-of-turn actions, pending choices, hidden-card and
   log/seed leakage, duplicate/stale commands and disconnected clients.
2. **Desktop LAN hosting (implemented; physical-network playtest pending):** player-hosted private IPv4
   listener, pinned TLS invitations, opt-in decentralized LAN discovery,
   temporary names and reconnects. No central auth, directory or ranking.
   Validate two physical computers and firewall behavior as well as local
   sockets. Separate Identity, Host Game,
   Game Browser and waiting-room windows lead into a full-screen classic
   duel interface; local name remembering is not account creation.
3. **Full-pool guest duel adapter (implemented; playtesting ongoing):**
   shipped/saved full deck lists and the complete implemented registry. Online play
   uses the actual `DuelScreen`, with its layout, combat window, target gestures,
   mana-payment flow, phase stops, card animations and audio. Its render-only
   projection contains only the authorized seat view; the host alone runs rules.
   Private choices, authorized reveals and hidden-zone transitions are explicit.
   Keep expanding mechanic and malformed-message tests. Durable replay and the
   wider offline match/rules options remain separate work; registry coverage
   is not a claim that every card interaction has been playtested online.
4. **Internet guest hosting/discovery:** choose a cross-platform transport,
   bootstrap/peer-exchange mechanism and relay fallback; review privacy,
   abuse limits and the untrusted-host model. Test desktop-to-web play,
   loss/reconnect, duplicates, overload and incompatible versions. Do not
   claim crash recovery until a restored match really continues.
5. **Optional accounts and MElo (parked):** choose maintained authentication,
   recovery and result-assurance policies only when returning to this scope.
   Higher-assurance ranked play needs approved referees and audited,
   idempotent results. Casual player hosting does not require accounts.
   Rated tournaments and tournament-integrated drafting remain later work;
   LAN knockout tournaments are implemented
   ([guide](sgmanalink-tournaments.md)).

Every implementation milestone must retain existing regression gates and
offline compatibility. Hosting budget/provider, official domain, auth
stack and public policies remain decisions to make for future online services.
No paid service or public Internet listener is configured. Temporary LAN
capabilities intentionally do not reserve permanent identities or MElo history.

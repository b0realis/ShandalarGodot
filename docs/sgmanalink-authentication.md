# SGManalink authentication and hosting options

Status: planning note, checked 2026-09-14. Development remains on
`sgmanalink`. (2026-10-27: no longer — that branch was merged into `main`
and only `main` exists; LAN play is developed there, and the Internet
hosting this note plans for is parked since 2026-09-15.) **Use temporary guest names while improving the game
experience.** No official domain or authentication provider has been chosen;
no external service, account, billing arrangement or public listener has
been created. Provider details below are a dated shortlist, not a deployment
decision or a promise that a free tier will remain unchanged.

**Current priority: decentralized player-hosted LAN games, without Nakama,
central authentication or ranking.** The account services below are future
options only, not requirements for this milestone. The desktop LAN prototype
uses ephemeral certificate-pinned invitations and temporary guest seats.

See the [local playtest](sgmanalink-local-playtest.md),
[online design](sgmanalink-design.md) and the separate
[block-MElo exploration](block-MElo.md).

## What works without a permanent identity

The LAN/loopback Identity window lets a player enter or generate an optional
temporary nickname before connecting, with explicit opt-in remembering of that
display name on the device. The server appends its guest number, for example
`Forest Fox (Guest 2)`. Leaving the field blank gives `Guest 2`.

- Names are display text, not credentials or global reservations.
- Duplicate nicknames are allowed; guest numbers distinguish sessions within
  one service run, not across computers or future service restarts.
- Names use up to 20 ASCII letters, numbers, spaces, hyphens or underscores.
  The server validates the input; markup and forged parenthesized guest
  suffixes are not accepted as nickname syntax.
- The accepted label stays with the temporary seat through reconnection.
  Only its secret resume capability restores that seat, never its nickname.
- Closing the lobby forgets the client's seat credentials; only an explicitly
  remembered display-name preference survives. The service retains
  its bounded in-memory session records until it stops. Nothing is an account,
  recoverable profile, name claim or MElo record.

Permanent authentication need not block work on the duel interface, deck
selection, choices, targeting and reconnect behavior. However, temporary
names do not make an Internet-facing service safe: public guest play would
still require secure transport, session authorization, abuse limits and
the other public-service gates. The current implementation supports desktop
private-IPv4 LAN hosting and opt-in local discovery, not public Internet
hosting. A table is **open** by default: its LAN listing carries the
invitation itself, so anyone on the private network who sees the listing
joins with a click — the trust boundary is the network. **Invitation only**
keeps the secret and the certificate out of every listing; only the players
the host sends the invitation to can connect, and the listing's certificate
fingerprint still checks a pasted invitation against the host that is
actually listening. The [playtest guide](sgmanalink-local-playtest.md)
documents the encrypted invitation transport and host-trust limits.

## Do we need a server running all the time?

For future accounts and ranked play we need **available services**, not
necessarily a dedicated machine that we own or keep awake. For the current
LAN milestone, only the players' computers are required; the host must stay
running. The following table describes the future account-backed model:

| Responsibility | What needs to be available | Who could operate it? |
|---|---|---|
| Authentication | Registration, sign-in, credential recovery, session/token renewal and public verification keys | A managed identity provider, or our maintained self-hosted deployment |
| Player registry | Stable PlayerIDs, canonical handles, identity-provider bindings, moderation/session state and later MElo | Our backend and durable database; could later be federated |
| Lobby and duels | Room discovery, invitations, legal game actions, reconnects and match recovery | Our game service and headless referee workers |
| Web build and downloads | Static game files, help and optional assets | Static hosting/CDN; this alone cannot run the referee or account database |

A managed identity provider hosts the login infrastructure for us. It does
not automatically host SGManalink's custom player registry, match browser
or Godot engine. Some backend platforms include database/functions too,
but those have their own limits and do not automatically run a persistent
native Godot process.

With self-hosted authentication, someone must operate the service and its
durable database whenever sign-in/recovery is expected to work. That can
be a server, container platform or managed deployment; a developer laptop
that is occasionally switched off is not an always-available public login
service. Scale-to-zero infrastructure may be appropriate for some requests
if cold starts and state persistence are acceptable, but not by assuming
live match state survives in process memory.

Authentication need not be contacted for every card action. A reviewed
backend can validate suitable signed, unexpired tokens using trusted cached
verification keys and maintain its own bounded game sessions. Define key
rotation, revocation and session expiry explicitly. An identity-provider
outage may block new sign-ins or renewal without automatically losing an
already-authorized duel; it must not result in accepting unknown keys,
indefinitely expired sessions or bypassing authorization.

## Requirements for a maintained authentication backend

These are acceptance criteria for a future integration, not implemented
features of the local prototype.

1. **Supported standards and maintenance.** Prefer an actively supported
   OpenID Connect/OAuth component with passkeys, documented security updates,
   provider status information and a clear supported-version policy. Do not
   implement password storage, WebAuthn verification or token cryptography
   inside card scripts.
2. **All four platforms.** Desktop clients use the system browser with
   Authorization Code + PKCE and registered redirects; no embedded shared
   client secret. Validate state/nonce as appropriate and bind callbacks to
   the initiating request. Web sign-in uses the intended HTTPS origin and
   a reviewed session design. Test Linux, Windows, macOS and browser exports
   rather than assuming a JavaScript SDK integrates directly into Godot.
   [Native-app OAuth guidance](https://www.rfc-editor.org/rfc/rfc8252.html).
3. **Separate identity from profile.** Map the validated `(issuer, subject)`
   pair to our stable PlayerID. Never identify or automatically merge people
   by display name, email or an untrusted submitted subject. Support deliberate,
   strongly authenticated account linking and provider migration.
4. **Token and request validation.** Use maintained middleware to validate
   signatures, approved algorithms, exact issuer, audience, expiry and token
   purpose; an ID token is not an API access token. Limit privileges and
   lifetime. Protect browser sessions against CSRF and cross-origin abuse,
   and authorize room/seat actions on the server. WSS does not supply these
   controls itself. [OWASP WebSocket guidance](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html).
5. **Recovery and session control.** Multiple credentials/devices, an agreed
   recovery route, logout/revocation, stolen-device handling and strong checks
   before changing credentials. Test recovery as carefully as login. Knowing
   a nickname is never enough to recover it.
6. **Pseudonymity and minimal data.** No legal name or public email in the
   game. Check whether the provider requires a private email for enrollment
   or recovery; that is different from showing it to opponents. Prove the
   chosen no-email or private-email flow before promising it. Keep provider
   identifiers, tokens and recovery data out of public room listings/logs.
7. **Operations and administrator security.** TLS, restricted administration,
   protected signing credentials, rate limits, monitoring, tested backup
   restoration, incident response and a named maintainer. With a managed
   provider, review which of these are included and which remain ours.
8. **Portability and cost controls.** Exportable account mappings, tested
   migration, data-location/retention choices, quotas, billing alerts and
   spending limits where available. A free plan's account count is not an
   uptime, unlimited traffic, recovery or backup guarantee.

The passkey private key belongs in the authenticator/password-manager
system, not our user database. Credential public records and identity
metadata still need careful storage and recovery. Authentication proves
account control; it does not prove one person per account or honest games.

## No official domain yet: what can be tested?

Provider-assigned HTTPS tenant domains can be used for disposable tests;
local development can use the provider's supported localhost flows. We do
not have to buy a domain just to continue guest-mode game development.

Before real long-lived persona enrollment, choose the intended issuer,
login domain and WebAuthn relying-party ID, and document who controls them.
Passkeys are scoped to a relying party, so moving domains/providers cannot
be treated as simply copying a list of users. Re-enrollment or a supported
migration arrangement may be needed. Do not reserve real player handles or
attach future MElo to throwaway tenant accounts.
[WebAuthn specification](https://www.w3.org/TR/webauthn-3/),
[Auth0's domain-migration considerations](https://auth0.com/docs/customize/custom-domains/multiple-custom-domains/passkeys).

## Free-service shortlist

Verified against the linked official pages on **2026-09-14**. MAU means
monthly active users; DAU means daily active users. Those measures are not
interchangeable and are not counts of simultaneous duels. Recheck live
terms, account eligibility and every required feature before choosing.

| Candidate | Advertised free offering | Fit and important limits for SGManalink |
|---|---|---|
| Nakama / Heroic Cloud | Nakama's open-source server can be self-hosted without a software subscription. An ongoing free **managed hosting** tier was not verified on Heroic Cloud's public pricing page. | A game-backend candidate with an official Godot SDK, not just a login provider. Heroic Cloud advertises managed deployments and a smaller development tier, but the accessible calculator did not expose a dependable numeric quote; do not assume that development tier is free. [Nakama](https://heroiclabs.com/nakama/), [hosting pricing](https://heroiclabs.com/pricing/) |
| Auth0 | Up to 25,000 MAU; passkeys included; one custom domain, with credit-card verification required for that feature | A candidate for hosted OIDC/browser sign-in. Free account creation does not require a card. Does not host our referee or player registry. Verify recovery, pseudonymous enrollment, quotas and migration in a test tenant. [Pricing](https://auth0.com/pricing) |
| ZITADEL Cloud | 100 DAU, unlimited stored users and all security features advertised on the free plan | A candidate for a small hosted identity pilot. Passkeys are a documented feature. Custom domains are advertised in paid Pro; confirm the needed free-plan domain/branding entitlements. Pro is advertised from US$100/month, so evaluate the upgrade path. [Pricing](https://zitadel.com/pricing), [features](https://zitadel.com/features) |
| Supabase | 50,000 MAU, 500 MB database, two active free projects; free projects pause after one week of inactivity | Useful auth-plus-database prototype option, but not an always-available guarantee. Passkeys are now documented as **experimental**, with APIs subject to change, so do not assume production-ready passkey suitability. [Pricing](https://supabase.com/pricing), [passkey status](https://supabase.com/docs/guides/auth/passkeys) |
| Keycloak, self-hosted | Open-source identity software, not a free hosted-service allowance | A control-oriented alternative with OIDC and self-managed deployment. We would supply and maintain compute, database, TLS, backups and availability. Free software is not free operation. [Project](https://www.keycloak.org/), [production deployment](https://www.keycloak.org/server/configuration-production) |

**Assessment:** Nakama merits an early evaluation for the broader game
backend. Auth0 and ZITADEL remain candidates for a dedicated hosted identity
service; these are not necessarily mutually exclusive choices. Keycloak is
worth comparing if independent operation is a priority. Supabase's current
passkey status and free-project pausing need explicit consideration. This
is not a provider selection, tested Godot integration, or a guarantee of a
zero-cost launch.

Custom-domain support does not include purchasing/renewing the domain.
Email delivery, SMS, extra traffic, storage, support and game compute may
cost separately. Avoid SMS as a default dependency unless specifically
needed. Do not add payment details, enroll real players or activate a paid
upgrade without a separate deployment decision.

### Nakama: promising for the game, with a separate rules referee

Heroic Labs provides an official Godot 4 client SDK and documents account
sessions, matchmaking, match listing and competitive features. This could
reduce the amount of general game-backend plumbing we maintain while the
front end keeps its Shandalar appearance. Verify the selected SDK against
our pinned Godot and all four exports before adopting it.
[Godot client guide](https://heroiclabs.com/docs/nakama/client-libraries/godot/index.html).

The main architectural distinction is that Nakama's embedded server logic
runs in Go, JavaScript/TypeScript or Lua, not GDScript. Its Godot SDK is a
**client** integration, not a way to run `MtgGame` inside Nakama.
[Server runtime documentation](https://heroiclabs.com/docs/nakama/server-framework/introduction/).
Our preferred integration to evaluate would therefore be:

- Nakama manages game accounts/sessions, room metadata, invites and discovery.
- Separate headless Godot workers run the existing authoritative rules engine
  and expose only each seat's permitted state.
- A server-side bridge assigns authenticated players to workers using scoped,
  short-lived match tickets. Referee results are accepted idempotently from
  trusted workers; clients cannot write their own wins or MElo scores.

Do not port the full MTG engine merely to fit a backend's runtime, and do not
replace a referee with client-relayed state. Availability, worker deployment,
ticket validation, result persistence and private-room access checks remain
integration work, not automatic SDK features.

Authentication also needs deliberate policy. Nakama supports device, email,
social and custom authentication. Device/custom IDs used as credentials must
not be public nicknames or hardware IDs. Its security guidance explicitly
warns against `OS.get_unique_id()` and recommends securely generated random
device credentials instead. Possession of a copyable device credential is
not the same as a recoverable multi-device passkey account. The SDK's embedded
application/server key is not an individual player's secret or an admin key.
[Authentication guidance](https://heroiclabs.com/docs/nakama/concepts/authentication/).

For future passkeys, do not assume a native turn-key WebAuthn flow from the
listed authentication methods. Evaluate an external maintained identity
provider plus a server-side custom-auth hook that verifies its proof before
mapping to the Nakama account. Never accept a public PlayerID as sufficient
custom-login proof or auto-link accounts by nickname. Review every enabled
authentication/linking path so a weaker route cannot bypass the stronger one.
[Third-party authentication integration](https://heroiclabs.com/docs/nakama/guides/concepts/custom-authentication/).

Nakama's tournament/leaderboard features are useful building blocks, but
must be checked against our desired elimination/Swiss progression, booster
drafts and MElo policy; a scheduled score competition is not automatically
an MTG bracket and draft system.
[Tournament documentation](https://heroiclabs.com/docs/nakama/concepts/tournaments/).

Self-hosted Nakama still needs an available server and database. It is not
a decentralized identity ledger simply because its source is open. No
Nakama SDK, runtime or cloud account is installed or configured by this note.

### What about free hosting for our own service?

Free application hosting is a different question from free authentication.
For example, Render's free web services spin down after 15 minutes without
inbound traffic and use ephemeral local files; its free PostgreSQL databases
expire after 30 days. Render explicitly says not to use free instances for
production applications. These are useful disposable experiments, not a
durable identity/match-store plan. [Render free-instance limits](https://render.com/docs/free).

For the real service, evaluate a small paid or community-sponsored host,
or a suitable managed platform, against actual workload measurements and
recovery needs. A donated server also has electricity, bandwidth, security
and maintenance costs. Do not promise permanently free hosting or generate
artificial traffic to work around a provider's idle policy.

## Decentralized alternatives

Decentralization can change who operates identity and who is trusted; it
does not remove storage, connectivity, recovery or moderation requirements.

- **Friend-to-friend game-only keys.** Players could generate dedicated
  credentials locally and prove possession when joining a private game.
  Friends would verify fingerprints through a trusted separate channel;
  trust-on-first-use alone cannot detect a substituted key on that first
  contact. This can avoid a central login provider, but gives no globally
  reserved nickname, built-in recovery or official MElo. Connection discovery,
  NAT traversal and browser-compatible relays are separate problems.
- **Federated identity providers.** Independent community operators could
  authenticate their members, using names qualified by realm and explicit
  trust relationships. Each provider still needs available infrastructure.
  Account portability, issuer validation, recovery and compromised-provider
  handling require agreement; federation is not automatically failover.
- **Shared identity ledger.** A community validator network could agree on
  name ownership, key changes and ranked records. It still needs online
  validators, independent operators, bootstrap trust and safe recovery.
  A replicated file alone provides neither those decisions nor proof of
  honest match results. See [block-MElo](block-MElo.md) for the alternatives
  and their assumptions rather than treating a blockchain as a free auth host.

None of these is implemented by the current temporary nickname field.
In particular, a player-operated host holding all hidden game state remains
outside the official ranked trust boundary regardless of the login scheme.

## Next decision, when gameplay is ready

Keep the current game work independent of external accounts. A future
evaluation should use disposable users and prove: registration, duplicate
name handling, browser-to-desktop callbacks, two-device passkeys, recovery,
revocation, provider downtime, account export and migration on all four
platforms. Select the provider/domain only after that review and the cost,
privacy and operating responsibilities are acceptable.

Public and private guest duels can be a separate future milestone, with
clear unrated labels and secure short-lived sessions. Permanent personas
and MElo remain later decisions; anonymous guest play must never silently
become a claim to an established player's name or rating.

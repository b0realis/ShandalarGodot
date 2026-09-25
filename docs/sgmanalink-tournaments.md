# LAN tournaments

Development implementation on `main`, **0.40.12** (protocol **24**). Internet play, permanent accounts,
MElo and tournament-integrated drafting are parked. A separate
[timed draft builder](booster-draft.md) is available for local practice.
Windows, Linux and macOS use the existing LAN
transport; this does not add web multiplayer.

## Format and deck policy

One organiser hosts 2–20 entrants, with up to five rounds. Each pairing is first to 1, 2 or 3 wins
(normally one game, best of three or best of five; drawn games do not count
towards the win target). Random fresh pairings are drawn for each round;
first-round byes fill the next power of two. The organiser cannot reroll a
published draw. All tables in a round may play concurrently.
If later withdrawals leave an uneven field, the next draw can include a bye.
For twenty entrants, the first draw has four played pairings and twelve byes;
the next round has eight parallel matches. A full event has nineteen played
series. Byes are shown explicitly, never counted as played wins.

Choose one fixed deck for everyone, a host-approved list of decks, or let
each entrant bring a shipped/saved deck. Registration validates the complete
implemented card pool and locks each deck for the whole tournament. No ante,
sideboarding or deck changes between games. Current LAN duel rules apply.

The organiser may [fill a chosen number of seats with computer players](sgmanalink-computer-players.md)
during registration. All four local difficulties are available, plus the separate
Unfair challenge. Add batches to mix decks/levels; bots count toward the same
limit, follow the same deck policy and ready automatically for each game.

## Organiser and players

A graphical Master Panel shows registration, pairings, series scores, table
progress and connections. Its organiser may enter or remain outside the draw,
close registration, draw the next round, withdraw an entrant with confirmation,
pause and resume the whole event, declare or correct a series result with
confirmation, cancel the event and recover saved progress. The referee
determines every game result; the organiser's two other marks on the ledger
are flagged as theirs for every player. Withdrawal awards the
opponent the series, visibly marked as a withdrawal rather than a played win.
An already eliminated entrant cannot be withdrawn afterwards to rewrite results.

**Pause tournament** (running events only) freezes every table, the
organiser's own included, and opens no new one; a game action at a paused
table is refused with the pause notice, and **Draw next round** waits for
**Resume tournament**. Withdrawals, rulings and cancellation stay available
while paused. The pause lives in the host application: a host restart lifts
it. A failed save pauses the event the same way, with **Retry save** as the
way out — and **Cancel tournament** and **Close** still work under it, so a
folder that has stopped taking saves never keeps an event alive that the
organiser wants ended.

**Declare … winner** on a table of the current round ends that series at once
with the named player as its winner; a game in progress ends there, the way a
withdrawal ends one. **Correct: … wins** on a finished table of the current
round overturns the recorded result, whether the referee, a withdrawal or an
earlier ruling wrote it; a correction of the final moves the championship.
Played scores are never rewritten: the ruled pairing keeps the games as they
were played and carries the reason **Organiser's ruling** or **Corrected by
organiser** on every round card, in the Advancement diagram and in its own
Standings column. Only the current round can be ruled on — a published draw
closes the round before it — and a withdrawn player cannot be ruled the winner.

The hall has five sections:

- **Overview:** organiser controls, current tables, scores, turns and life totals.
  A pairing that has not started names the players it is still waiting for,
  rather than saying it waits for both after one of them has confirmed.
- **Advancement:** a connected round diagram. Arrows follow actual published
  winners, not guessed future opponents. Scroll, zoom, fit the width or choose
  **Whole draw**; select a player to highlight their route through the event.
- **Standings:** all entrants, played series W–L, games W–L–D, byes, forfeit
  awards/losses, ruled awards/losses and status. Completion opens the final
  table automatically.
- **Players:** connection/readiness status, deck titles and organiser withdrawals.
- **My entry:** one plain line for the player's own seat, plus deck review,
  readiness, recovery code and return to the hall. The line names the table
  and opponent still to confirm, who the pairing waits for, a bye with no
  game to play, the series just won or lost, the wait for the other tables,
  the wait for the next draw, an elimination, a withdrawal and the finished
  event. No screen in the hall leaves a waiting player without a sentence.

Final places reflect elimination round, not an invented tiebreaker. With no
third-place game, the semifinalists share third; other same-round eliminations
also share a place. For an uninterrupted twenty-player event, places are 1, 2,
two at 3, four at 5, eight at 9 and four at 17. Alphabetical display within a
shared place is not a competitive advantage. Cancellation or completion without
a champion does not assign final ranks. These are event results, not MElo points.

Discoverable tournaments appear by name in the normal **Game Browser**. An
open event (the default) publishes its invitation in that listing, so **Join**
connects a guest at once and the Tournament Hall opens. An invitation-only
event is listed by name but its listing is not authentication: guests still
paste the organiser's private invitation and connect. A host unlisted in the
game browser can be joined directly with its invitation.

The organiser chooses the tournament name and an optional **280-character
welcome message** before opening registration. The greeting appears as plain
text in every visitor's hall, before and after joining, and stays available
without interrupting duels. It is saved with the event and restored on reload;
it is not broadcast in discovery packets.

Players join from the Game Browser or with the invitation, register and choose a deck,
then confirm readiness. A finished duel returns to the Tournament Hall rather
than closing the hosting application. Human players confirm before another game
in a series starts. The organiser can open the Master Panel during their duel.
Different players may join or ready simultaneously without conflicting. Each
ready action is tied to the current round and game attempt, so an old delayed
click cannot ready a later match. Host controls still require the current ledger.

## Recovery contract

The host remains trusted and must keep running. Each human entrant receives a separate
private recovery code; copying/saving it is explicit. Nicknames never reclaim
an entry. The checkpoint contains decklists and recovery-code hashes, not live
hands, library order, random seeds, transport credentials or plaintext codes.
It is private organiser data, not a public replay.

Completed game scores and pairings are saved. After an explicit restore the
host issues a fresh invitation; entrants reclaim their entries with their
codes. An interrupted game starts again from opening hands with both players
ready; previously recorded wins remain. There is no seamless host migration.
Save failure suspends tournament advancement. The organiser reads the storage
instruction they can act on; every other hall says that play resumes when the
organiser retries the save and that recorded scores are kept.
The organiser's own **Forget** empties the organiser's chair, not the event:
the resume code goes with the session, but an event in registration or under
way keeps running at its tables and its checkpoint stays current. The host's
own lobby takes the chair back with the seat it holds next, without a table
restarting; nobody else can, and a connected organiser is never displaced.
A host whose network drops loses nothing either way: every tournament seat,
the organiser's included, is held for its resume code past any duel's
reconnect grace, and when the network is back each seat is where it was —
same table, same hands, same controls. Only a host restart goes through the
checkpoint and the recovery codes below.
Recovery requires a matching build and the same enabled gameplay packs. Earlier
development checkpoints remain untouched but are not migrated across a changed
build fingerprint. Use matching 0.40.12 builds and enabled packs for recovery.
Computer entries retain their settings and are recreated without recovery codes.

**Tournament setup → Save folder** offers a typed path, **Browse…** and
**Default**. The choice is remembered on this host and refreshes the saved-event
list immediately. New events save there; existing checkpoints are never moved.
The default is `user://tournaments`. Relative paths, resource-pack paths and
existing files are refused. The host reports an unwritable folder when saving.
Folder paths never enter the public tournament configuration or LAN packets.

An ordinary duel has a five-minute reconnect grace. Tournament entrants are
instead reserved until the organiser explicitly withdraws them or ends the
event. Losing a connection is not an automatic series loss, and a host outage
never silently selects a winner. Without the saved recovery code, a new
application cannot reclaim an entry by matching its nickname.

## Play on a LAN

1. Use matching builds (0.40.12 uses protocol 24) and enabled card packs. Open the globe, choose a
   temporary name, and check the LAN address/port under **Host Game →
   Network settings…** if the computer has several adapters.
2. Open **Tournament**. Name the event, choose 2–20 maximum entrants and a
   first-to-1/2/3 win target. **DECKS → Change…** opens the deck policy
   (own, fixed or approved decks); for fixed or approved decks, search,
   review and add the required list(s) there. Up to sixteen approved decks
   may be offered. **Welcome message…**, **Save folder…** and **Saved
   tournaments…** open their own windows. The event is **open** by default:
   players on the network find it in their Game Browser and register with a
   click. Switch on **Invitation only** to admit only the players you send
   the invitation to; **Copy invitation** sits beside the switch and again
   in the hall's header. Then **Open registration**.
3. Guests find the tournament in **Game Browser** (one row, named after the
   event) and choose **Join**. An open event connects them at once; an
   invitation-only event asks for the invitation the organiser sent, which
   **Join by invitation…** also accepts directly. Connecting opens the hall
   and its welcome.
4. Each entrant chooses **Join tournament**, selects/reviews a deck, copies
   their private recovery code, and selects **Ready for tournament**. The
   organiser can join too, or keep all twenty places for guests.
5. In the **Master Panel**, choose **Start tournament**. Each paired player
   chooses **Ready for next game**. Both must be ready before their normal
   duel screen opens. The introduction shows the round, game and series score.
6. Dismiss the result to return to the hall. If the series needs another game,
   both confirm readiness again; otherwise wait for the next draw. **My entry**
   says which of those is happening and updates as the other tables finish.
   The organiser chooses **Draw next round** after all pairings finish. No draw
   can be rerolled and no client can report an arbitrary winner; the
   organiser's own rulings are flagged as such wherever the result is shown.

**Expand Master Panel** opens a full-window overview. During the organiser's
own duel, the **Tournament** button opens the same panel without disconnecting
the host; their own table stands still behind it, like any other duel window,
while the referee and every other table keep running. The panel is opaque and
covers the ordinary notice line, so a control the host refuses — drawing the
next round while an advancing player is still away, for instance — prints its
answer inside the panel. It shows pairings, scores, drawn games, life totals, turns and entrant
connections. Withdrawals, rulings and cancellation require a second confirmation click.
**Return finished tables to hall** releases completed result screens without
affecting live games, and is offered only while a table is actually finished. **Finish hosting this tournament** returns the service to
ordinary duel hosting after completion/cancellation and all tables are released.

To recover after a host restart, choose the saved event under **Tournament**,
share its fresh invitation, then have entrants **Recover my entry** with their
codes. New names are display-only and do not replace the registered entry.
Checkpoint files are described in [the player-file guide](player-files.md).

## Twenty-player verification

The later [eight-player varied-deck campaign](sgmanalink-eight-player-campaign-2026-09-15.md)
adds duplicate/reconnect stress, per-game results and a mana-trigger regression
for the network test bot. Its findings are distinguished from gameplay defects.

A real-TLS campaign completed all nineteen full engine games of a twenty-player
knockout, with a separate organiser and up to eight live tables. Both permitted
seat views agreed on the public state after every accepted command. The pilots
receive only their own allowed view, not the host engine or another player's
hidden cards. Seed 4242 completed **9,766 commands** and passed **29,693 assertions**, wrapper exit **0**, in
387.499 seconds. This is network-interface coverage, not a measurement of the
ordinary gameplay AI's strategic strength.

Run the extended campaign from the project root:

```sh
SG_TOURNAMENT_CAMPAIGN_PLAYERS=20 SUITE_TIMEOUT=900 ./run_tests.sh \
  -gselect=test_sgmanalink_tournament_network.gd \
  -gunit_test_name=test_full_games_through_parallel_tables_and_final_use_only_seat_views
```

The normal suite keeps a shorter four-entrant, three-full-game campaign, plus
a twenty-entrant complete knockout using concessions and a simultaneous
twenty-entrant registration/readiness check. These are sockets on one Mac;
physical LAN and mixed-platform play remain manual acceptance checks.

All **31 tournament tests / 15,229 assertions** passed together, wrapper exit
**0**, in 79.064 seconds. This includes exact schema and recovery checks for
every entrant count from two to twenty across four seeds, full-capacity
simultaneous joins/readiness, stale next-game readiness, reserved organiser
sessions, omitted entrants, phantom tables, twenty-row standings and graph
geometry/state preservation.

Fresh native Godot source-scene previews were inspected at 1280×800 and
960×600. They use staged names/scores, not a physical LAN event. The diagram,
zoom controls, setup and parchment standings header render correctly; long
names are clipped with full tooltips, and long lists/draws scroll. All capture
wrappers exited 0 with fresh capture markers and no runtime warnings or errors.

Final whole-project acceptance passed **6,459 tests / 266,328 assertions /
383 scripts**, wrapper exit **0**, in 451.407 seconds. No failing, skipped or
risky tests, runtime errors or exit-time leaks were accepted; the existing
harness warning and two deprecations are unchanged. The run includes the
ordinary baseline/fault network campaign and all thirty-one tournament tests.
Offline engine/card behavior and normal computer-player policies are unchanged.
This verification is of the source tree; no new binary export, commit, push
or public release replacement was performed in this twenty-player pass.

## Earlier eight-player milestone verification

The automated tournament checks exercise nine real TLS clients (eight entrants
and a separate organiser), every roster size from two to eight, random byes,
all three win targets and deck policies, duplicate results, draws, withdrawals,
private entry recovery, host restart and failed/corrupt checkpoint recovery.
Three full engine games play through concurrent first-round tables and a final
using only each client's permitted view: seed 4242, 1,542 accepted commands.
The ordinary twelve-game baseline/fault campaign also produced identical public
transcripts across delays, duplicate sends and lost-acknowledgement reconnects.

Real Godot source-scene previews were inspected with the original skin at
1280×800 and 960×600, including configuration and the expanded Master Panel.
The preview uses staged entrant names/scores; it is not a photograph of remote
players. Final captures exited cleanly. An earlier capture-only Dummy-audio
teardown warning was removed by stopping the preview's soundtrack before exit.

The first full run passed 6,446 of 6,447 tests; the sole failure was an obsolete
menu-text assertion. The assertion now checks the LAN-only scope, and a separate
failing-before/passing-after regression covers closing an expanded Master Panel
when its event ends. Final whole-project acceptance passed **6,447 tests /
257,413 assertions / 382 scripts**, wrapper exit **0**, in 428.865 seconds.
That final run uses the standard two-game network campaign; the extended
twelve-game campaign above had already matched all baseline/fault transcripts.
All nineteen tournament tests passed in the full run. No runtime errors,
skipped/risky scripts or exit-time leaks were accepted; the existing harness
warning and two deprecations are unchanged.

Four offline interface-logic duels also finished under the isolated headless
runner, seed 4242: Fifth Edition demo/human seats took 19/12 turns; modern
took 17/13. Both wrappers exited 0 without errors, warnings or stalls, matching
the prior offline baseline. Native rendering is covered separately by the
source-scene previews above.

The earlier protocol-8 local Linux x86-64 and universal macOS builds use the existing verified
desktop-template policy. The Mac app passed isolated startup and strict ad-hoc
signature checks. The Linux game pack booted under the Mac editor runtime from
its export folder; native Linux execution still requires a Linux playtest.
Those ZIPs contain only the app or executable/game pack and LAN instructions,
with separate checksums. Existing skin and card art can be reused. No old build,
public release, branch history or player profile was overwritten. Those older
builds do not include the twenty-player changes; rebuild all peers together.

These are automated sockets on one Mac, not a completed physical LAN playtest.
Test on two or more computers using matching builds, including both host roles,
concurrent tables, disconnect/reconnect and explicit host restart. No public
release announcement or replacement is implied by this development work.

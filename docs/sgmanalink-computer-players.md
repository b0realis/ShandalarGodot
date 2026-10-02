# Computer players on a LAN

SGManalink offers the same **Apprentice, Magician, Sorcerer and Wizard**
opponents as local duels, with Wizard selected initially. Choose their deck
from the full implemented shipped/saved catalogue, review the list, and choose
Quick, Normal or Leisurely pacing. Pacing changes the delay between decisions,
not playing strength. Settings are fixed when the duel starts.

**Unfair — sees your hand** is a separate, unchecked challenge modifier. It
locks Wizard while enabled and restores the chosen fair level when disabled.
This uses the existing `UnfairPlayer`, not an extra difficulty rung or a global
hand reveal. Rooms, tournament rosters, match introductions and the duel's
existing Unfair badge disclose the challenge. LAN play remains unrated.

## Duel rooms

Connect to a host and create a duel room. When the opponent seat is empty,
use **Play against the computer** to choose its level, challenge, pace and
deck, then **Add computer seat(s)**. Select your own deck and **Ready**.
The computer is ready automatically. The room creator can remove it before
play, then add another configuration or invite a human instead.

A connected guest can create a computer duel on the trusted LAN host too;
they do not need to run a second referee. A bot cannot replace an occupied
human seat or be reconfigured during play. Losing the human connection pauses
that duel. Reconnecting keeps the same game and computer player. Leaving the
finished room releases the computer seat and its table.

## Tournament seats

Open registration, then use **Master Panel → Overview → Computer players**.
Choose how many seats to add, the level/challenge and the deck. Add several
batches for mixed levels or decks. Human and computer entrants together must
fit the configured 2–40 entrant limit. Only the organiser may add bots; remove
an unwanted entry in **Players** before starting. The roster and bot settings
lock with registration.

Bots follow the same fixed/approved/own-deck policy as humans. They have no
special bracket privileges: the same random pairing, byes, wins-to-advance,
draws and final standings apply. Bots ready themselves for each game and
return to the hall after the referee records its result. Human players still
confirm each new game. The organiser still draws each new round; adding bots
does not enable automatic tournament control.

The organiser may stay outside an all-computer draw and follow its public
scores, life totals and turns. This does not add a private-hand spectator mode.
Saved tournaments retain bot configurations/decks and recreate their seats on
restore. A full host refuses restoration before installing a partial roster;
free unused guest seats and retry. Interrupted games restart, just as human games do. Bots receive no
recoverable login token; a human cannot reclaim one as their own seat. A failed
checkpoint save pauses computer play as well as human advancement until the
organiser retries successfully.

## Implementation and fairness

These are **host-managed engine players**, not the simplified network-coverage
pilot. `SgBotPlayer` constructs the shipped player/profile and schedules it at
the referee. Each action uses `MtgGame`'s public rules APIs; mulligans use its
opening API, and card choices, cleanup and damage use its normal decision agent.
No AI strategy, card rules or difficulty capabilities were changed for LAN play.

The standard policies keep the [fair-information contract](fair-play.md):
own hand/list, public state and rule-authorised information, not the opposing
hidden hand, secret library order or future draws. Only explicitly constructed
Unfair players may use the opposing current hand. Human clients still receive
only their allowed views. The host contains the complete referee and must be
trusted; these policies are not protection against a modified host executable.

Work is paced per table and round-robin scheduled with a soft frame budget.
A single bounded decision cannot be preempted; twenty simultaneous Wizards
may still run slower on an older host. No bot work is done in a client GUI.

This is deliberately distinct from a remote Wizard command adapter: bot actions
do not travel out over TLS and back into the referee. TLS tests exercise human
commands, configuration, publication, recovery and tournament controls; the
existing DTO-only campaigns continue to exercise every remote command path.

## Verification

Run from the project root:

```sh
./run_tests.sh -gselect=sgmanalink_bot
./run_tests.sh -gselect=sgmanalink
./run_tests.sh
```

On 2026-09-15 the focused bot gate passed **16 tests / 620 assertions**, with
wrapper exit **0**. The whole-project gate passed **6,477 tests / 269,323
assertions / 386 scripts**, wrapper exit **0**, in **455.023 seconds**.
The Python tool gate completed **227 tests** with its one
Linux-path check skipped on macOS. Native menu captures at **1280×800** and
**960×600** were rendered and inspected; their temporary setup was removed.

The bot integration campaign runs an eight-Wizard event using five different
shipped starter decks (three repeated), draw seed **4250**, game seeds
**4250–4256**. All seven games completed with played results, no draws or
forfeits; Wizard bot 7 with **Blue Skies** won three series. The organiser's
TLS client received final standings without any participant hand. This is
one deterministic integration scenario, not a statistical strength comparison.

Other checks cover the four actual profiles, the separate Unfair constructor,
fair hidden-state substitution and public-change controls, Wizard's Manabarbs
payment handling, mixed human-command/Wizard play, reconnect suspension,
recreated bots after host restart, organiser-only filling, capacity, deck policy,
save failure, multi-game readiness, settings persistence and GUI containment.
Native screenshots use staged source-scene menus, not a physical LAN event.
Same-Mac TLS and source rendering do not certify two-machine or mixed-OS LAN play.

The save-pause regression first reproduced `[6] expected to equal [5]: no bot
action may follow the failed save in this poll`. Automatic readiness had failed
to save, but another live table could take one more action before the next
update noticed the failure. The scheduler now rechecks the save gate immediately
after automatic readiness, as well as before scheduling and after results.

The restore-capacity regression reproduced a successful restore with only one
free session for two saved bots. Restoration now checks capacity for the whole
bot roster before saving or installing the event, so no missing computer seat
can silently stall a restored draw.

The unpaced mixed-game test also reproduced `BOT RATE LIMIT: 65 commands in
one second`, followed by stale-revision refusals after reconnect. Its click
driver now waits for a newer acknowledged view and sends at most 25 commands
per second. The production 64-message/s safeguard remains unchanged; refusals
are still test failures rather than suppressed retries.

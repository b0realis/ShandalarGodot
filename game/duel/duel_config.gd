class_name DuelConfig
extends RefCounted
## Everything the battle-setup screen decides, in one object the duel
## screen consumes: who pilots each seat (human or an AiProfile), which
## decks, starting life, pacing, and hand visibility. The setup screen
## builds one and hands it over on "Go"; standalone scene runs and tests
## use the static constructors.

## Deck card lists per seat (already loaded/validated).
var decks: Array = [[], []]
## Display names per seat.
var player_names: Array[String] = ["Player 1", "Player 2"]
## Which DECK each seat brought, by name — what the pre-duel splash means
## by "playing with High Priest". Empty when nobody said (a scene run, a
## test), and the splash then simply omits the line.
var deck_names: Array[String] = ["", ""]
## The portrait each seat chose ([PortraitLibrary] ids). Empty falls back
## to the seat's duelist face, which is derived from the deck's colour.
var portraits: Array[String] = ["", ""]
## Starting life per seat (the adventure layer will feed real values here).
var lives: Array[int] = [20, 20]
## Per-seat pilot: null = human, or an AiProfile for an AI seat.
var pilots: Array = [null, null]
## Seconds between AI actions (demo mode slows this for followability).
var pace := 0.35
## Sidebar wizard-panel color keys per seat.
var panel_colors: Array[String] = ["white", "black"]
## THE `&Ante` MATCH PARAMETER (`@SHELLPAGE_SINGLEDUEL`,
## `Program/UIStrings.txt:48`; the same checkbox on `@SHELLPAGE_GAUNTLET`
## `:70` and `@SHELLPAGE_SEALEDDECK` `:90`) — how many cards
## each seat stakes before the opening hands are dealt. 0 = not playing
## for ante, which is what a bare DuelConfig means so that nothing
## programmatic (tests, the Deck Lab, benchmarks) loses a card from a
## library it did not ask to lose one from. The battle-setup screen ticks
## it ON by default, because Shandalar itself always plays for keeps
## (manual p.165: *"Most duels are played 'for keeps'"*).
var ante := 0

## THE MATCH PARAMETERS the original's screen sets beside `&Ante`
## (`@SHELLPAGE_SINGLEDUEL`, `Program/UIStrings.txt:47-50`). `best_of` is
## 0 for `&Free play` — one
## duel and no record — or one of [constant MatchState.LENGTHS]; the whole
## rule lives in [MatchState]. `sideboard_between_duels` is the checkbox
## that puts `Side&board...` on the between-duels window.
##
## Both default to the free-play values, so a DuelConfig built by anything
## that has not asked for a match (the Deck Lab, the tests, a standalone
## scene run) is exactly the single duel it was before matches existed.
var best_of := MatchState.FREE_PLAY
var sideboard_between_duels := false
## Per-seat sideboards — the `SB:` lines [DeckList] has always parsed and
## round-tripped. Until matches landed nothing read this field, which is
## why the Deck Builder declined to edit it (docs/ROADMAP.md); the
## between-duels sideboard step is the reader it was waiting for.
var sideboards: Array = [[], []]
## The FORMAT the decks were required to meet ([DeckFormat]) — one of the
## original's five. Recorded rather than enforced here: the setup screen
## refuses an illegal deck before a config is ever handed over, so by the
## time a duel sees this it is a statement of what was played, which is
## what a bug report and the Deck Lab's report both want.
var deck_format := DeckFormat.UNRESTRICTED

## RNG seed for the whole duel — shuffles, the opening toss, every coin
## flip and random choice. 0 = pick a fresh one per duel. The duel screen
## rolls a real seed when this is 0 and LOGS it, so any duel can be
## replayed from a bug report by setting it here.
var rng_seed := 0


func is_ai(pid: int) -> bool:
	return pilots[pid] != null


## Hands rendered face-down: AI seats in mixed games; nothing in hotseat;
## nothing in a demo (watching both hands is the point of a demo).
func hidden_seats() -> Array[int]:
	var hidden: Array[int] = []
	if is_ai(0) and is_ai(1):
		return hidden
	for pid in 2:
		if is_ai(pid):
			hidden.append(pid)
	return hidden


## Dominant color key of a deck (drives the wizard life-panel art).
static func dominant_color(cards: Array) -> String:
	var counts := {"white": 0, "blue": 0, "black": 0, "red": 0, "green": 0}
	var by_mask := {Mtg.ManaColor.W: "white", Mtg.ManaColor.U: "blue",
		Mtg.ManaColor.B: "black", Mtg.ManaColor.R: "red", Mtg.ManaColor.G: "green"}
	for card_name in cards:
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		for mask in by_mask:
			if data.color_mask() & mask:
				counts[by_mask[mask]] += 1
	var best := "white"
	for key in counts:
		if counts[key] > counts[best]:
			best = key
	return best


static func hotseat_default() -> DuelConfig:
	var config := DuelConfig.new()
	config.decks = [StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS]
	config.player_names = ["White Wizard", "Black Wizard"]
	config.apply_deck_colors()
	return config


## Set each seat's panel colour from its DECK's dominant colour — the
## colour the most cards in it are. That colour drives the seat's whole
## look: the wizard life panel, the terrain the half is tiled with, the
## graveyard plate, and the hand window's border. The setup screen already
## derived it per deck; deriving it here too means every entry point
## (standalone scene runs, the demo, tests) obeys the same rule instead of
## carrying a hardcoded guess.
func apply_deck_colors() -> void:
	for pid in 2:
		panel_colors[pid] = dominant_color(decks[pid])


static func vs_ai_default(profile: AiProfile) -> DuelConfig:
	var config := hotseat_default()
	config.pilots = [null, profile]
	config.player_names[1] = "AI %s" % profile.profile_name
	config.pace = Settings.ai_pace()
	return config


static func demo_default() -> DuelConfig:
	var config := hotseat_default()
	config.pilots = [AiProfile.wizard(), AiProfile.wizard()]
	config.player_names = ["AI White", "AI Black"]
	config.pace = 0.8   # human-followable
	return config

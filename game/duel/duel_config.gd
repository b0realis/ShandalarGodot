class_name DuelConfig
extends RefCounted
## Everything the battle-setup screen decides, in one object the duel
## screen consumes: who pilots each seat (human or an AiProfile), which
## decks, starting life, pacing, and hand visibility. The setup screen
## builds one and hands it over on "Go"; standalone scene runs and tests
## use the static constructors.

## Deck card lists per seat (already loaded/validated).
var decks: Array = [[], []]
var printings: Array = [{}, {}]
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
## Pass-and-play privacy, enabled by battle setup for Hotseat. Bare configs
## and hotseat_default remain open two-human fixtures for tools and tests.
var hotseat_privacy := false


## Separate opt-in challenge, not an AiProfile knob or a fair ladder rung.
var unfair: Array[bool] = [false, false]
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
## Public archive grouping only; never a shuffle seed or identity token.
var record_match := ""
var record_started := ""
var record_game := 1
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

## MAGIC BATTLE'S `Test hands` (2026-10-19): the hand-built position this
## duel begins from ([DuelPosition]), or null — every other duel. A config
## that carries one is a TEST, and the duel screen reads that one fact to
## skip everything a test is not: the ante, the splash, the coin toss, the
## opening hand and its mulligans, and the running `duel_log.txt`; its
## Pause window offers `Restart test` and its `Exit duel` goes back to the
## Test hands screen. Made by [method for_test] and nowhere else.
var position: DuelPosition = null
## A test's table shows BOTH hands, the computer's too, when the player
## ticked `Show both hands` on the Test hands screen: whoever built the
## position already knows them, and a test is about seeing why a play was
## or was not made. Display only — what an AI seat may READ is not this
## screen's to widen (rule 8).
var open_hands := false


## Is this duel a `Test hands` duel ([member position])?
func is_test() -> bool:
	return position != null


## THE TEST DUEL this config's seats, decks and pilots play: the same
## everything, beginning from [param test_position] on [param seed_value].
## Always ONE free-play duel — no match, so no match record and no
## [AiMatchMemory]; never for ante; never a private hotseat (one person sat
## down at both seats to build it, so there is nothing to hide between
## them). The life totals are the position's. The position is COPIED, so
## the screen that built it may go on editing its own.
func for_test(test_position: DuelPosition, seed_value: int, show_hands := false) -> DuelConfig:
	var out := DuelConfig.new()
	for pid in 2:
		out.decks[pid] = (decks[pid] as Array).duplicate()
		out.printings[pid] = (printings[pid] as Dictionary).duplicate()
		out.sideboards[pid] = (sideboards[pid] as Array).duplicate()
	out.player_names = player_names.duplicate()
	out.deck_names = deck_names.duplicate()
	out.portraits = portraits.duplicate()
	out.pilots = pilots.duplicate()
	out.unfair = unfair.duplicate()
	out.pace = pace
	out.panel_colors = panel_colors.duplicate()
	out.deck_format = deck_format
	out.hotseat_privacy = false
	out.ante = 0
	out.best_of = MatchState.FREE_PLAY
	out.sideboard_between_duels = false
	out.rng_seed = seed_value
	out.position = test_position.duplicate_position()
	out.lives.assign(out.position.lives)
	out.open_hands = show_hands
	return out


func private_hotseat() -> bool:
	return hotseat_privacy and not is_ai(0) and not is_ai(1)


## Keep saved names intact; seat annotations belong to this hotseat duel.
func seat_name(pid: int) -> String:
	if private_hotseat():
		return "%s (%s)" % [player_names[pid], "below" if pid == 0 else "above"]
	return player_names[pid]


static func seat_label(pid: int) -> String:
	return "Player %d (%s)" % [pid + 1, "below" if pid == 0 else "above"]


func is_ai(pid: int) -> bool:
	return pilots[pid] != null


func create_ai(pid: int) -> AiPlayer:
	return UnfairPlayer.new(pid) if unfair[pid] else AiPlayer.new(pid, pilots[pid])


func challenge_label() -> String:
	var seats: Array[String] = []
	for pid in 2:
		if is_ai(pid) and unfair[pid]: seats.append(str(pid + 1))
	if seats.is_empty(): return ""
	if is_ai(0) != is_ai(1):
		return "Unfair · Hand visible to opponent"
	return "Unfair · Hand knowledge (seat %s)" % ", ".join(seats)


## Static visibility for mixed games and open fixtures. Private hotseat
## concealment is managed per decision by DuelScreen, not by pilot type.
## A demo has no private hands; DuelScreen keeps both stacks openly visible.
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
	# DUPLICATED, because a `const` Array reaches its readers READ-ONLY in
	# GDScript 2.0 and a config's deck is something the game edits: the
	# Match screen's sideboard moves a card between `config.decks[pid]` and
	# `config.sideboards[pid]` in place ([method MatchScreen.move_one]), and
	# on a config built here `remove_at` failed with "Array is in read-only
	# state" while the `append` on the other side went through — so the
	# card was in BOTH piles and the move reported success.
	config.decks = [StarterDecks.WHITE_KNIGHTS.duplicate(),
		StarterDecks.BLACK_RED_RAIDERS.duplicate()]
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

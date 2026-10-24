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

# --- part B (W2): what an adventure duel asks of the duel ---
#
# A MEETING WITH A CREATURE SETS THE DUEL UP ITSELF (`play_duel`'s Shandalar
# branch, `duel.c:2205-2526`; b3/b4 specs): the stakes it drew, who moves
# first, the cards in play, a mirrored deck, and 1997's own opening rules.
# Every field below is OPT-IN — its default is exactly the duel every other
# screen plays — and seat 0 is always the adventurer, seat 1 the creature,
# as `play_duel` seats them. [method plays_named_ante] /
# [method adventure_opening] say whether a config asks for any of it.

## THE NAMED STAKES, per seat: `[[names], [names]]`, each card LIFTED OUT OF
## THAT SEAT'S LIBRARY into its ante before the deal (1997 marked them out
## of the deck, `duel.c:2360-2370`) — the creature's ante card drawn at the
## meeting, the adventurer's stake. The decks must hold them.
## [method MtgGame.stake_named_ante].
var ante_cards: Array = [[], []]
## STAKES FROM OUTSIDE THE DECK, per seat: `[[names], [names]]`, MADE
## straight into that seat's ante, owned by it — a lair's hoard of rares,
## or the adventurer's own card when it plays a creature's deck ("Why
## don't you try this deck!"). [method MtgGame.stake_extra_ante].
## Either list, even both empty for one seat, plays the duel FOR ANTE, and
## then [member ante]'s random count is not used. Nothing settles these
## stakes when the duel ends: the adventure reads [DuelReport] and moves
## its own cards.
var ante_extras: Array = [[], []]
## WHO MOVES FIRST: -1 is the coin toss and the toss winner's choice (every
## duel until now); 0 or 1 makes that seat start — NO toss and NO play or
## draw question, the opening window saying only `@DIALOG_MULLIGAN`'s first
## two lines, "%s will start first" / "You will take the first turn"
## (`duel.c:2315-2325`: First Strike, the adventurer's first-move gift).
var first_player := -1
## CARDS IN PLAY AT THE START, per seat: `[[names], [names]]`, each made
## and put onto the battlefield under that seat's control after the
## opening hands and before turn 1, its entering running
## (`duel.c:2502-2526`: the creature's card, the adventurer's next-duel
## card). [method MtgGame.arrange_opening].
var start_in_play: Array = [[], []]
## MIND CONTROL (`duel.c:2483-2499`): seat 1's library becomes a shuffled
## copy of seat 0's and its opening hand a copy of seat 0's hand as it
## stands after the mulligans. [method MtgGame.mirror_opening].
var mirror_seat0 := false
## THE MULLIGAN: "" is ours (the Paris rule, any hand, one card fewer each
## time — the owner's ruling of 2026-09-08); [constant MtgGame.MULLIGAN_1997]
## is the adventure's — seat 0 may redraw seven for free only with no land
## or all land, seat 1 redraws by the creature's own rule.
var mulligan_rule := ""
## 1997'S TOSS WINNER AT THE COMPUTER'S SEAT chooses play or draw at random,
## 50/50 (`dlgproc_duel_coin_flip`, `internal_rand(2)`): "and will play
## first." / "and has chosen to draw first." False keeps ours — the
## computer always takes the play.
var ai_random_play_or_draw := false
# --- end part B (W2) ---

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
## THE MAGIC BATTLE SCREEN'S starting lives a test was built under. A
## test's own [member lives] are its position's, so before this the bench
## that `Edit test` reopened took the last test's lives for its `Clear
## all` to go back to, where its tooltip promises the starting lives
## (fixed 2026-10-21). Empty on a config [method for_test] did not make:
## read it through [method starting_lives].
var setup_lives: Array[int] = []


## Is this duel a `Test hands` duel ([member position])?
func is_test() -> bool:
	return position != null


# --- part B (W2) ---
## Does this duel name its stakes ([member ante_cards] /
## [member ante_extras])? Then it is played for ante whatever they hold,
## and the random [member ante] count is not used.
func plays_named_ante() -> bool:
	for list in [ante_cards, ante_extras]:
		if seat_names(list, 0).size() + seat_names(list, 1).size() > 0:
			return true
	return false


## Seat [param pid]'s names in a per-seat list (`[[names], [names]]`) —
## empty for a list too short or not a list, so a config built by hand
## cannot break the deal.
static func seat_names(list: Array, pid: int) -> Array:
	if pid < 0 or pid >= list.size() or not list[pid] is Array:
		return []
	return list[pid]


## Does this config ask for anything of the adventure's opening — a forced
## first move, cards in play, Mind Control, 1997's mulligan or toss choice,
## or named stakes?
func adventure_opening() -> bool:
	return plays_named_ante() or first_player >= 0 or mirror_seat0 \
		or mulligan_rule != "" or ai_random_play_or_draw \
		or seat_names(start_in_play, 0).size() + seat_names(start_in_play, 1).size() > 0
# --- end part B (W2) ---


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
	out.setup_lives.assign(starting_lives())
	out.lives.assign(out.position.lives)
	out.open_hands = show_hands
	return out


## The lives a fresh test begins with: the Magic Battle screen's, however
## many tests ago this config came from it ([member setup_lives]).
func starting_lives() -> Array[int]:
	return lives if setup_lives.is_empty() else setup_lives


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

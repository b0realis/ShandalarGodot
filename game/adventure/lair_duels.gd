class_name LairDuels
extends RefCounted
## THE FOUR LAIR DUELS (part B, 2026-10-23) — 1.3's `RunLairExplorationEvent`
## cases 9, 10, 11 and 13 (world_lair_monster_encounter.c 1130–1186) and the
## duel they run, `RunRandomCreatureAnteDuel` (517–601), headless: what the
## duel is ([method begin]), the duel handed to the engine ([method
## duel_config]) and what it leaves ([method settle]). The pane is the lair's
## own ([LairPane]); the duel is held over the world by [WorldDuels], as every
## adventure duel is.
##
## | Lair                 | Tier                         | Rares staked | First        |
## |----------------------|------------------------------|--------------|--------------|
## | 9 Abandoned Shrine   | 8, 13 once the siege clock   | 2 (3 at 13)  | —            |
## |                      | has run 256 steps            |              |              |
## | 10 Dragon's Lair     | 18                           | 4            | —            |
## | 11 Hall of the Sultan| 13                           | 2            | King Suleiman|
## |                      |                              |              | the next     |
## |                      |                              |              | duel's card  |
## | 13 Spectral Arena    | 16 (the Spectre's life)      | 3            | a creature   |
## |                      |                              |              | 1–54 drawn   |
##
## IN 1997'S ORDER, on the adventure's dice ([member AdventurePlayer.dice]):
## `Aswanjag.wav` (`sfx_lair_duel`, the pane's); the Hall's gift set
## ([member AdventurePlayer.next_duel_card] "King Suleiman", csv id 436 —
## before anything is drawn or asked, so it stays when the hero leaves
## quietly, and the quest pane shows it); the Arena's creature
## (`rand(54) + 1`); THE CREATURE'S STAKE, N rares not of its deck — each
## [method LairEvent.rare_of_any_kind] (rarity 3 or more, any kind, a
## dungeon's treasure not left out: 1997's `internal_rand(g_card_count −
## 0x39)` until rare and available; two alike may come); THE CREATURE,
## [method CreatureBook.pick] at the tier, any colour, drawn again while it
## is 55 or above (Arzakon's rows); the words (`@MONSTERLAIR` 0–4: "You
## encounter %s / Genie | Spectre | Dragon guarding a horde / of valuable
## spells." by the tier 13, 16, 18, else "warily guarding a horde"; "Will
## you... / Leave quietly. / Duel the creature.").
##
## THE DUEL ([method duel_config]): the creature plays its MAINDECK (1997's
## `LoadCreatureDuelDeck(row, …, 0, −1)`, colour filter 0 — no section it
## learned is added here) at strength 3 with no hand modifier; its colour is
## its first; THE HERO STAKES NOTHING (`global_ante_cards[0][0] = −1`); the N
## rares are the creature's stake, made into its ante, never part of its deck;
## no test of the hero's usable cards (`ExitIfNoUsableDeckCards` is not
## called); the creature's life its tier + 2 a difficulty step; every
## next-duel gift of the hero's played as in any duel (the Hall's King
## Suleiman in play).
##
## WHAT IT LEAVES ([method settle]; every next-duel gift spent first, as after
## any duel, visitLocation.c 2196–2231):
##  - A WIN: `Winbak01.pic` (`win_back_cards`) and the win music; each card
##    laid at x = s·i + 111 − (N−1)·s/2, s = 300/(N+1), at y = `rand(10)` +
##    16 (one die a card; 1997's 320-wide page, [method won_places]) over its
##    rarity (`@BROWSE` 15, 16: "Rare", "Unique"); the cards join the
##    collection IN NO DECK (`AddCardToDeckSorted`, then `deck |= 0x4000`:
##    [method AdventurePlayer.add_card], which writes "Acquired spell: %s" for
##    each rare as 1997's adder did; a full bag loses the card); then
##    `@MONSTERLAIR` 5 "Won These Cards".
##  - A LOSS: nothing is lost.
##  - NO JOURNAL LINE, NO VICTORY LOGGED, no win or loss counted: 1997 writes
##    only the lair's "Discovered a %s" ([LairEvent]).
## Then the lair ends as every lair does: its waiting rare, if any, is found
## ([method LairEvent.finish]).
##
## FIXED [ours: 1997 slips, the lead's defaults under the owner's ruling 1]:
##  - A DRAW CHANGES NOTHING (1997 counted any result but 0 a win,
##    `RunDuelEngine(…) != 0`: a draw won the hoard).
##  - THE SPECTRAL ARENA fights the creature it draws (`rand(54) + 1`, any of
##    rows 1–54, any tier or kind) AS A SPECTRE — its own deck and face, named
##    "<creature> Spectre" in the duel, at tier-16 life (16 + 2 a difficulty
##    step) — as its words say ("You encounter a Witch / Spectre guarding a
##    horde"). 1997 copied that creature into row 56 at tier 16 (name,
##    article, plural, gender, deck) and then picked a tier-16 creature with a
##    pick that throws back every row from 55: the copy was never fought, the
##    hero met an ordinary tier-16 creature. The tier-16 pick is still drawn
##    here, as 1997 drew it, so the dice go on as they did; row 56's own life
##    (+50 a step, Arzakon's) is not used. [CreatureBook]'s table is never
##    changed.
## [QoL, ours] The Hall of the Sultan says so: "(King Suleiman starts in
## play!)" — 1997's own `@DUNGEON` 18, "(%s starts in play!)", which the
## dungeons say of their gifts; 1997's Hall said nothing.
##
## DESIGNED, NEVER USED (dead in 1997, dead here; for
## `docs/adventure-unused-1997-features.md`):
##  - THE CREATURE'S STRENGTH 3 AND ITS COLOUR (`g_current_encounter_strength
##    = 3`, `g_current_encounter_color` its first colour, E:567–570): set for
##    the duel and read by nothing that takes effect — the strength only feeds
##    the dead hand size (§2: a creature of strength 3 would open with
##    `3 + difficulty + 4` cards, 7 to 10), the colour only a castle wizard's
##    life. Switched on with §2, every lair creature would open with three
##    cards more than a weak roaming one on the harder levels: the hoards
##    would be guarded harder. To switch on: §2's hand size, fed 3 here.
##  - THE SIGNATURE CARD PASSED TO THE DECK LOADER. Every lair duel loads the
##    creature's deck with its signature card's id (`LoadCreatureDuelDeck(row,
##    find_internal_card_id_by_csv_id(deck_number), …)`, E:566), and the
##    loader ignores it (`(void)name_id`, visitLocation.c 2320–2324) — as
##    every other caller's. What it was for is not said (the card the deck is
##    named after: kept out of the stake? put in play?); it needs a meaning
##    before it can be switched on — [method CreatureBook.signature_card] is
##    the card.

## The duel's results, seen from the hero (as [DuelReport]'s).
const WON := 1
const LOST := 0
const DRAWN := -1
## Each duel lair's tier and the rares its creature stakes (the Shrine's
## later ones in [constant SHRINE_LATE]).
const SETUPS := {
	LairEvent.SHRINE: [8, 2],
	LairEvent.DRAGON: [18, 4],
	LairEvent.SULTAN: [13, 2],
	LairEvent.ARENA: [16, 3],
}
## The Abandoned Shrine once the siege clock has run [constant LATE_SIEGE]
## steps (`g_siege_timer < 0x100` the early one).
const SHRINE_LATE: Array[int] = [13, 3]
const LATE_SIEGE := 256
## The Arena's creature: `rand(54) + 1` — 1997's `rand(creature rows − 3) +
## 1`, the rows before Arzakon's.
const ARENA_ROWS := 54
## The Spectre's tier: its life is this + 2 a difficulty step.
const ARENA_TIER := 16
## The first of Arzakon's rows: a lair's pick is drawn again from here.
const ARZAKON_ROW := 55
## The Hall of the Sultan's gift (csv id 436).
const KING_SULEIMAN := "King Suleiman"
## The sound before every lair duel (`Duelsounds/Aswanjag.wav`).
const SOUND := "sfx_lair_duel"
## `@MONSTERLAIR`, as 1997 words it (Advstrings.txt; 0-based): 0–3 the
## creature by the tier (13, 16, 18, else), 4 the question and its choices,
## 5 the cards won.
const ENCOUNTER: Array[String] = [
	"You encounter %s \nGenie guarding a horde\nof valuable spells.",
	"You encounter %s \nSpectre guarding a horde\nof valuable spells.",
	"You encounter %s \nDragon guarding a horde\nof valuable spells.",
	"You encounter %s \nwarily guarding a horde\nof valuable spells."]
const WILL_YOU := "Will you..."
const LEAVE_QUIETLY := "Leave quietly."
const DUEL := "Duel the creature."
const WON_CARDS := "Won These Cards"
## `@DUNGEON` 18 — the Hall's line [QoL, ours].
const STARTS_IN_PLAY := "(%s starts in play!)"
## The Spectre's name in the duel [ours].
const SPECTRE := "%s Spectre"
## [Ours] Said under the cards won when the bag could hold no more of them.
const BAG_FULL := "Your magic bag holds no more spells."
## 1997's page for the cards' places: 320 units wide ([method stake_places],
## [method won_places]).
const PAGE_WIDTH := 320.0
const CARD_WIDTH := 80.0


## Whether lair event [param kind] ([constant LairEvent.SHRINE] …) is a duel.
static func is_duel(kind: int) -> bool:
	return kind in LairEvent.DUELS


## `[tier, rares]` of lair event [param kind] for [param player] (the
## Shrine's by the siege clock); `[0, 0]` for no duel.
static func setup_of(player: AdventurePlayer, kind: int) -> Array[int]:
	if not is_duel(kind):
		return [0, 0] as Array[int]
	if kind == LairEvent.SHRINE and player.siege_timer >= LATE_SIEGE:
		return SHRINE_LATE.duplicate()
	var pair: Array = SETUPS[kind]
	return [int(pair[0]), int(pair[1])] as Array[int]


# ------------------------------------------------------------- the setup --

## THE LAIR'S DUEL SET UP for lair [param event] ([method LairEvent.begin]),
## drawn now in 1997's order (see the class doc) and kept in the event
## (`duel`), so a second call gives the same: `{kind, tier, count, rares,
## row, arena, gift, words, color}` — `row` the creature fought (0: none
## could be drawn, no duel), `arena` true for the Spectre, `gift` the card
## the Hall set in play for the next duel ("" none), `words` the lines said.
## `{}` for a lair that is no duel.
static func begin(player: AdventurePlayer, event: Dictionary) -> Dictionary:
	var kind := int(event.get("event", 0))
	if not is_duel(kind):
		return {}
	if event.has("duel"):
		return event["duel"]
	var pair := setup_of(player, kind)
	var setup := {"kind": kind, "tier": pair[0], "count": pair[1], "rares": [] as Array[String],
		"row": 0, "arena": kind == LairEvent.ARENA, "gift": "", "words": [] as Array[String], "color": 1}
	if kind == LairEvent.SULTAN:
		player.next_duel_card = KING_SULEIMAN
		setup["gift"] = KING_SULEIMAN
	var dice := MsvcRandom.new(player.dice)
	var arena_row := 0
	if kind == LairEvent.ARENA:
		arena_row = dice.below(ARENA_ROWS) + 1
	for n in int(setup["count"]):
		# The hoard is the creature's stake: never limited, under the
		# Classic MTG rules too (the owner's ruling; c12, h2-1).
		var rare := LairEvent.rare_of_any_kind(dice)
		if rare != "":
			(setup["rares"] as Array[String]).append(rare)
	var row := 0
	while true:
		row = CreatureBook.pick(dice, 0, int(setup["tier"]))
		if row < ARZAKON_ROW:
			break
	player.dice = dice.state
	# [Ours: 1997 slip — the Arena's own creature is the one fought; the
	# tier-16 pick above is drawn as 1997 drew it, and set aside.]
	if arena_row > 0:
		row = arena_row
	setup["row"] = row
	setup["color"] = first_color(row)
	setup["words"] = words(setup)
	event["duel"] = setup
	return setup


## The creature's colour for the duel: the first of its colours (1 black …
## 5 white; `single_color_test_bit_to_color_t`), 1 for none.
static func first_color(row: int) -> int:
	for color in range(1, 6):
		if CreatureBook.is_of(row, color):
			return color
	return 1


## THE WORDS (`@MONSTERLAIR` 0–4) for [param setup], a line each as 1997
## broke them: the creature by its tier with its article, the Hall's gift
## [QoL], "Will you...".
static func words(setup: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var row := int(setup.get("row", 0))
	if row <= 0:
		return out
	var text: String = ENCOUNTER[3]
	match int(setup.get("tier", 0)):
		13:
			text = ENCOUNTER[0]
		16:
			text = ENCOUNTER[1]
		18:
			text = ENCOUNTER[2]
	for line in (text % CreatureBook.called(row)).split("\n"):
		out.append(line.strip_edges())
	if String(setup.get("gift", "")) != "":
		out.append(STARTS_IN_PLAY % String(setup["gift"]))
	out.append(WILL_YOU)
	return out


## The choices (`@MONSTERLAIR` 4): Leave quietly, Duel the creature —
## `[id, words, ready]`, the duel `lair_duel` (not ready with no creature).
static func choices(setup: Dictionary) -> Array:
	return [["leave", LEAVE_QUIETLY, true], ["lair_duel", DUEL, int(setup.get("row", 0)) > 0]]


## Who the duel is against, for its questions and the duel's name: the
## creature's name, the Arena's "<name> Spectre" [ours].
static func foe(setup: Dictionary) -> String:
	var name := CreatureBook.name_of(int(setup.get("row", 0)))
	return SPECTRE % name if bool(setup.get("arena", false)) else name


## The creature's stake laid over the lair (`RunRandomCreatureAnteDuel`,
## E:526–535): card i of [param count] at (150/N·i + 100, 10/N·i + 100) on
## 1997's 320-wide page (integer steps, as 1997 divided) — each card's top
## left, in page units.
static func stake_places(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := maxi(count, 1)
	for i in count:
		out.append(Vector2((150 / n) * i + 100, (10 / n) * i + 100))
	return out


## The cards won laid on `Winbak01.pic` (E:571–585): card i of [param count]
## at x = s·i + 111 − (N−1)·s/2 with s = 300/(N+1), y = [param heights]' die
## + 16 — each card's top left on 1997's 320-wide page.
static func won_places(count: int, heights: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var step := 300 / (count + 1)
	for i in count:
		var height := int(heights[i]) if i < heights.size() else 0
		out.append(Vector2(step * i + 111 - ((count - 1) * step) / 2, height + 16))
	return out


# -------------------------------------------------------------- the duel --

## THE MEETING RECORD the duel is built from ([method CreatureMeeting.meet]'s
## shape, set as 1997 set it for a lair, E:564–575): the creature, its first
## colour, strength 3, no hand modifier, its maindeck (filter 0), nothing
## special, the hero's stake none, the creature's the rares.
static func meeting_of(player: AdventurePlayer, setup: Dictionary) -> Dictionary:
	var row := int(setup.get("row", 0))
	return {"slot": -1, "row": row, "met_row": row, "color": int(setup.get("color", 1)),
		"kind": CreatureBook.kind(row), "at": player.position, "relation": CreatureMeeting.NONE,
		"wins": 0, "strength": 3, "base_strength": CreatureBook.base_strength(row), "bribe": 0,
		"quest": false, "hero_ante": [] as Array[String], "hero_ante_at": [] as Array[int],
		"creature_ante": (setup.get("rares", []) as Array).duplicate(), "no_ante": false,
		"sleight_used": false, "timer": player.monster_timer, "prepared": true,
		"total_wins": player.total_wins(), "modifier": 0, "filter": 0, "special": false,
		"events": [] as Array[String], "swap_row": 0, "summoned": 0, "card": "",
		"first_strike": false, "mind_control": false, "lair": int(setup.get("kind", 0))}


## THE CREATURE'S LIFE: its tier + 2 a difficulty step ([method
## CreatureBook.duel_life]); the Spectre's 16 + 2 a step, whatever row it
## is [ours: see the class doc].
static func life(player: AdventurePlayer, setup: Dictionary) -> int:
	var d := clampi(player.difficulty, 0, 3)
	if bool(setup.get("arena", false)):
		return ARENA_TIER + 2 * d
	return CreatureBook.duel_life(int(setup.get("row", 0)), d)


## THE DUEL HANDED TO THE ENGINE ([method CreatureMeeting.duel_config] for
## the record of [method meeting_of]): the hero's deck in use padded as in
## any duel, nothing of it staked; the creature's maindeck; the rares made
## into the creature's ante, never lifted from its deck (a rare its deck
## holds is staked as a card of its own); the lives ([method life]); the
## hero's next-duel gifts (the Hall's King Suleiman in play); the
## Spectre's name; the hero's playmat on their half ([method
## CreatureMeeting.hero_playmat]).
static func duel_config(player: AdventurePlayer, setup: Dictionary) -> DuelConfig:
	var config := CreatureMeeting.duel_config(player, meeting_of(player, setup))
	config.ante_cards = [[], []]
	config.ante_extras = [[], (setup.get("rares", []) as Array).duplicate()]
	config.lives[1] = life(player, setup)
	if bool(setup.get("arena", false)):
		config.player_names[1] = SPECTRE % CreatureBook.duel_name(int(setup["row"]))
	return config


# ------------------------------------------------------------- the end --

## THE DUEL SETTLED from [param report] ([param conceded]: "Exit duel" was
## taken — a loss): every next-duel gift spent; a win's cards the hero's, in
## no deck — `{result, cards, rarities, heights, places, kept, bag_lost,
## words}` (`heights` 1997's die for each card's place; `places`
## [method won_places]). A loss or a draw changes nothing [ours: 1997 slip
## — a draw won the hoard].
static func settle(player: AdventurePlayer, setup: Dictionary, report: DuelReport,
		conceded := false) -> Dictionary:
	var result := result_of(report, conceded)
	var out := {"result": result, "cards": [] as Array[String], "rarities": [] as Array[int],
		"heights": [] as Array[int], "places": [] as Array[Vector2], "kept": [] as Array[String],
		"bag_lost": [] as Array[String], "words": [] as Array[String]}
	player.clear_duel_gifts()
	if result != WON:
		return out
	var dice := MsvcRandom.new(player.dice)
	for card_name in setup.get("rares", []):
		var name := String(card_name)
		(out["cards"] as Array[String]).append(name)
		(out["rarities"] as Array[int]).append(rarity_of(name))
		(out["heights"] as Array[int]).append(dice.below(10))
		if player.add_card(name):
			(out["kept"] as Array[String]).append(name)
		else:
			(out["bag_lost"] as Array[String]).append(name)
	player.dice = dice.state
	out["places"] = won_places((out["cards"] as Array).size(), out["heights"])
	(out["words"] as Array[String]).append(WON_CARDS)
	return out


## The duel's result from the hero's side: [param report]'s, a loss when it
## was conceded or there is none, a draw when it never finished (as
## [method DuelSpoils.settle] reads it).
static func result_of(report: DuelReport, conceded := false) -> int:
	if report == null or conceded:
		return LOST
	if not report.finished:
		return DRAWN
	return report.result


## A card's 1997 rarity (1 common … 4 unique; [method CardShop.shop_rarity]),
## 0 for one the game does not know.
static func rarity_of(card_name: String) -> int:
	if not CardRegistry.has_card(card_name):
		return 0
	return CardShop.shop_rarity(CardValue.facts(CardRegistry.get_card(card_name)))

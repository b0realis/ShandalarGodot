class_name FinalBattle
extends RefCounted
## THE END: ARZAKON'S BATTLE, ITS SCORE, AND WHAT IT LEAVES (part C,
## 2026-10-27) — the rules of everything from the fifth castle wizard's fall
## to the adventure's end, headless: the finale's screens (the fifth
## wizard's choice, the portal on the world, the deck builder, the movie,
## the win, the Hall of Fame) call them. 1997: `HandleDefeatedWizardCastle`
## from its test "are all five beaten" (dungeonEncounter.c 1031–1105; retail
## database.c 1594–1758, step for step), `CalculateDungeonEndgameScore`
## (dE:1856–1888; retail engine_core.c 16975–16995, identical), the duel's
## set-up for Arzakon (duel.c 2207–2287, 2502–2520). The 1997 words are
## `@CASTLEWIN` 6–10 and `@QUESTFAILED` 1, 4, 5 (Advstrings.txt), word for
## word.
##
## THE SHAPE OF THE END (the owner's rulings of 2026-10-27, round P2): when
## the fifth wizard falls Arzakon appears and asks — "Face me now" or
## "Return to Shandalar first" [ours]. Returning, his portal stands on the
## world for the hero to enter when ready — ARZAKON'S PORTAL (below). Either
## way 1997's words with the score so far ([method banish_lines]) and the
## deck builder (cards move, nothing sold) come first; then the battle
## begins at ARZAKON'S DOOR ([method door]): the hero marked there and the
## adventure saved (1997 saved nothing from the fifth castle on); then the
## battle ([method duel_config]) and its result ([method settle]):
##  - A WIN — the movie, the win picture, the words with the years
##    ([method win_lines]), the stats; the adventure marked won with its
##    score ([member AdventurePlayer.ended], [member
##    AdventurePlayer.final]), its line in the [HallOfFame], the portal
##    petrified (the owner: *"The Arzakon portal is shown as petrified
##    monument!"*); then the hero ends the adventure or walks on in a world
##    at peace ([method roam], [method AdventurePlayer.at_peace]).
##  - A LOSS, A DRAW OR A CONCESSION — the quest has failed (1997's
##    `@QUESTFAILED` end, [method failed_lines]); under "Reload allowed" the
##    hero stays at the door with the attempt written in the record
##    ([member AdventurePlayer.final_attempts], the journal), under "One
##    life" the adventure is marked failed for good. [ours: 1997 slip C3-1
##    — the battle's result was never read (dE:1063): a loss, a draw or a
##    concession played the win, the movie and "The people rejoice!"]
##
## ARZAKON'S PORTAL (the owner, 2026-10-27: *"I would not put the portal at
## the fifth castle ruins but somewhere in the middle of the map
## approximately. If you choose to wander after the win, the portal is a
## monument made of stone (make it as a new asset), the arrow, log, journals
## also point you towards this."*) [ours]:
##  - WHERE ([method portal_tile]): the land tile nearest the map's middle
##    that is free — no site, castle, road or dungeon on it — and that the
##    hero can walk to from the castles (the walk's own rule: any land, the
##    eight ways, the sea and the map's edge walls, [HeroWalk]); searched
##    outward from the middle, nearest first, with no dice, so a world
##    always gives the same tile — over the whole map, so a middle of sea
##    or of an island cut off gives the nearest tile the hero can reach;
##    none reachable at all, the nearest free land. Kept free after: no dungeon
##    moves onto it ([method DungeonDoors.takes_dungeon]), no creature or
##    lair is made on it ([method WorldLairs.fill]).
##  - It stands from "Return to Shandalar first" — or from the door, for
##    one faced at once ([method door]) — open; after the win it is
##    petrified, the stone monument. A save from before this ruling, its
##    portal on the fifth castle's ruins, keeps it there: a portal standing
##    is never moved.
##  - THE POINTERS, open and petrified: the guide arrows ([method
##    portal_target], [method WorldStatus.targets]), a line in the quest
##    pane ([method portal_line]), and the journal — a line as it opens and
##    one as the hero chooses to roam after the win ([method roam]), each
##    with its place in the world's words ([method portal_where]) and
##    pinned to its tile on the journal's map. THE OPENING'S LINE ONLY WHEN
##    THE HERO SEES IT (the owner's ruling of 2026-10-28): written as he
##    chooses "Return to Shandalar first", or as he turns back from the door
##    after a lost battle ([method leave_door]) — once ([method
##    tell_portal]); never when he faces Arzakon at once (the portal then
##    stands silently, for a reload at the door, [method door]).
##  - BACK FROM THE DOOR (the owner's ruling of 2026-10-28, "Fight or
##    return"): under "Reload allowed", taken up again at the door after a
##    loss, the hero may face him again or return to Shandalar first — buy
##    cards, rebuild the deck — and enter the portal again; it stays open,
##    and the arrows, the panel and the journal go on pointing to it
##    ([method leave_door]).
##
## "ONE LIFE" IS TRUE IRONMAN (the owner's ruling of 2026-10-27: *"True
## ironman: closing mid-battle ends the adventure as a lost final battle; no
## way to retry."*) [ours]. Under it the door's save means THE BATTLE HAS
## BEGUN ([member AdventurePlayer.at_door]), and the [HallOfFame]'s file
## keeps the adventure's mark outside every save — "begun" at the door,
## "failed" at a loss, gone at a win ([method HallOfFame.one_life_state]).
## Taken up again ([method on_load], which the load calls), an adventure of
## one life not ended whose save stands at the door, or whose mark says the
## battle began or was lost — the autosave of a game closed mid-battle, a
## slot saved before the door — is a lost final battle: the quest failed,
## the adventure closed. Under "Reload allowed" nothing changes on a load.
##
## ARZAKON'S DUEL ([method duel_config]; dE:1051–1062): his row drawn on the
## adventure's dice as 1997's `PickRandomCreatureTypeForWizardTier(0, 100)`
## — 55 or 56, the same Arzakon; his deck 999, the maindeck alone (138
## cards); his life `100 · (difficulty + 1)` (duel.c 2280–2287, [method
## CreatureBook.duel_life]); Black Lotus, then Celestial Prism, in play for
## him from the start; 1997's coin toss and mulligan; the computer at the
## hero's difficulty; the hero's deck in use, padded with basic lands to
## the difficulty's least. Ours beside:
##  - the duel names him "Arzakon" (the owner's "Arzakon in the duel"; part
##    B's name for row 55 is @DECKFACES's "Uber Villain");
##  - NO STAKE [ours: 1997 slip C3-4 — the castle wizard's duel left the
##    hero's stake set, so the final battle set a card of the hero's deck
##    aside as an ante against none of Arzakon's, shown and never paid];
##  - THE HERO'S LIFE is a castle duel's (the owner's (a), "Fresh each
##    duel"): the mana links and the next duel's lives the world gave
##    ([method CreatureMeeting.hero_life]) — the castle's life pool does
##    not reach him (the lead's Q-POOL: the castle pool zeroed; 1997 let it
##    through, dE:1059 zeroing only the world's carried lives). A gift the
##    world gave for the next duel — lives, a card in play, the first move
##    — is spent here as in any duel (the owner's D-4: the world's gifts are
##    spent only by the duel that uses them).
##
## THE SCORE ([method score]; dE:1856–1888), the years Arzakon is banished:
##     score = 2 · ( 3 · ( −S − 2·R ) + Σ (k + 2) + 25 · #(k = 12) )
## S the sieges begun and towns fallen ([member AdventurePlayer.siege_count]
## — over the whole adventure [ours: 1997 slip — it was never saved, so a
## game loaded counted from 0 again; the owner's "sieges counted all
## game"]), R the towns a wizard holds, k each win's kind in the victory
## log ([member AdventurePlayer.duel_victories]); a castle wizard's win
## (kind 12) pays its designed 25 more [ours: 1997 slip — no castle win was
## ever logged; the owner's SC2, logged by part C's castle win]. Shown
## before the battle no lower than 0 (@CASTLEWIN 7); the final battle adds
## 10 years for each life Arzakon lost ([method final_score]) [ours: 1997
## slip C3-2 — 1997 paid `(100 − his life left) · 10`, which is "10 a life
## lost" only at Apprentice and below zero from Magician up whenever he kept
## more than 100; slip C3-3 — and added it to the unfloored base, so a hero
## told "0 years" could end with fewer].
##
## EVERY OPTION THE OWNER WEIGHED IS A RULE ([constant RULES]; the pure
## functions take another set), so a ruling is one line and the tests
## cover both sides.
##
## DESIGNED, NEVER USED — kept dead here (and in
## docs/adventure-unused-1997-features.md):
##  - THE RULED TOWNS IN THE END SCORE (D2): 6 years a ruled town (−2, ×3,
##    ×2), computed only once all five wizards had fallen, when no town can
##    be ruled — always 0 in 1997. Ours shows the score so far on the hero's
##    record ([method AdventurePlayer.score_so_far]), where a town held
##    costs 12.
##  - ARZAKON'S TIER × (difficulty + 1) (D3, dE:1052–1054): a signed byte
##    (100, −56, 44, −112), overwritten by kind 13's life rule. Switched on
##    (life from the tier + 50·d), 100/250/400/550 — broken from Magician
##    without a wider field. To switch on: [method CreatureBook.duel_life]
##    for kind 13 from the scaled tier.
##  - THE BATTLE'S COLOUR AND STRENGTH (D4, dE:1056, 1058): the fifth
##    wizard's colour, strength 3 — read only by the castle wizards' life
##    rule and the dead hand-size formula (duel.c 2245, 2289). Switched on
##    with hand sizes by strength, Arzakon would open with 3 + d + 4 cards.
##  - ARZAKON'S ROW AS A CREATURE MET (D5): pre-duel flag 0x80 and reward
##    card 29, Celestial Prism (creature_names_init.inc row 55) — no meeting
##    with him exists; the final battle puts the prism in play itself.
##    Nothing to switch on.

## Arzakon's row (56 is the same Arzakon, [constant CreatureBook.ROWS]).
const ROW := 55
## The tier 1997 asks for him (`PickRandomCreatureTypeForWizardTier(0, 100)`).
const TIER := 100
## In play for Arzakon from the start, in this order (dE:1061–1062; 1997's
## ids 17 and 29, card_id.h).
const IN_PLAY: Array[String] = ["Black Lotus", "Celestial Prism"]
## The wizards to beat.
const ALL_FIVE := 5
## Each win in the victory log is worth its kind + 2; a castle wizard's 25
## more (dE:1870–1880).
const KIND_STEP := 2
const CASTLE_WIZARD_YEARS := 25
## A town a wizard holds costs 2 in the inner sum; the sieges 1 each.
const RULED_COST := 2
## The years each life Arzakon loses banishes him for (@CASTLEWIN 8).
const YEARS_A_LIFE := 10
## 1997's own years term: `(100 − his life left) · 10` (dE:1078).
const AS_PLAYED_START := 100

## `@CASTLEWIN` 6–10 (Advstrings.txt 756–760), word for word.
const FIFTH := "You have defeated all five wizards!\nShandalar is free!\nPrepare to face the final challenge.\n"
const BANISH := "Your battles so far will banish the evil\nPlaneswalker Arzakon for %d years.\n"
const GOOD_LUCK := "Each life it loses in the Final Battle\nwill banish it for 10 additional years.\nGood Luck!\n"
const PROTECTED := "You have protected the\nplane of Shandalar for\nthe next %d years.\n"
const REJOICE := "The people rejoice!\n\nLife is good!\n"
## `@QUESTFAILED` 1, 4 and 5 (Advstrings.txt 791–797): the quest failed,
## Arzakon's minions have worn the hero down.
const FAILED := "Your Righteous Quest has Failed\n\n"
const WORN_DOWN := "The Evil Planeswalker Arzakon\nand his Gruesome Minions\nhave worn you down\n\n"
const SUFFER := "The people will suffer\na thousand more years of their oppression\nbefore another Savior shall rise up from amongst them\nto challenge the great Arzakon and his Slimy Minions\n"

## THE CHOICES' WORDS [ours, for the finale's screens]: Arzakon's question
## when the fifth wizard falls (the owner's own words, round P2 Q-PORTAL),
## and the hero's after the win (the owner: "The win also gives you the
## choice to end or return to roam Shandalar").
const FACE_NOW := "Face me now"
const RETURN_FIRST := "Return to Shandalar first"
const WIN_END := "End"
const WIN_ROAM := "Return to Shandalar"
## The portal's names on the world [ours]: open, and after the win.
const PORTAL_NAME := "Arzakon's Portal"
const MONUMENT_NAME := "Arzakon's Petrified Portal"
## Its words [ours]: the journal's two lines, the quest pane's line, and the
## place they name ([method portal_where]: "in the middle of Shandalar, east
## of Kraag Temple").
const OPENED_LOG := "Arzakon's Portal opened %s"
const PETRIFIED_LOG := "Arzakon's Portal turned to stone %s"
const OPEN_LINE := "Arzakon's Portal: %s"
const PETRIFIED_LINE := "Petrified Portal: %s"
const IN_THE_MIDDLE := "in the middle of Shandalar"
const OF_TOWN := "%s of %s"
const SOMEWHERE := "in Shandalar"
## The guide arrows' kinds for it ([method WorldStatus.targets]).
const PORTAL_KIND := "portal"
const MONUMENT_KIND := "monument"
## How near the map's middle (tiles) the portal must stand to be called
## "in the middle of Shandalar".
const MIDDLE_WORDS := 12
## Said under the quest-failed end when the adventure waits at the door
## ("Reload allowed") [ours, words for the owner].
const RELOAD_HINT := "Your adventure waits at Arzakon's door: load it to face him again."

## The portal's states ([member AdventurePlayer.portal]): open for the
## hero to enter, petrified once Arzakon is beaten.
const PORTAL_OPEN := "open"
const PORTAL_PETRIFIED := "petrified"
const PORTAL_STATES: Array[String] = [PORTAL_OPEN, PORTAL_PETRIFIED]

## How the battle came out for the adventure ([method settle]'s `outcome`,
## the end's record's `result`): won, or the quest failed.
const WON := "won"
const FAILED_END := "failed"

# --- the rules: each the owner's choice, the other side named ------------
## What a battle not won does: "loss ends" (the owner's Q-B) — or "as
## played", the win sequence whatever the result (dE:1063).
const AS_PLAYED := "as played"
const LOSS_ENDS := "loss ends"
## The years the battle adds: "lives lost", 10 for each life Arzakon lost
## (the owner's b2, @CASTLEWIN 8's promise) — or "as played", `(100 − life
## left) · 10`.
const LIVES_LOST := "lives lost"
## The base the years are added to: "floored", the base shown before the
## battle, no lower than 0 (the owner's C3-3) — or "as played", unfloored.
const FLOORED := "floored"
## The castle's life pool: "clean", never reaching Arzakon (the lead's
## Q-POOL under the owner's (a)) — or "as played", added to the hero's life.
const CLEAN := "clean"
## His name in the duel: "Arzakon" (the owner's) — or "as played", part B's
## @DECKFACES name, "Uber Villain".
const ARZAKON_NAME := "Arzakon"
## The rules in force: `result`, `years`, `base`, `pool`, `name` as above;
## `overkill` — whether a life below 0 counts as a life lost (true, as 1997
## and the b2 formula counted them; false caps the years at his starting
## life — an open question for the owner).
const RULES := {"result": LOSS_ENDS, "years": LIVES_LOST, "base": FLOORED, "pool": CLEAN,
	"name": ARZAKON_NAME, "overkill": true}


## [constant RULES] with [param rules] over them.
static func rules_with(rules: Dictionary) -> Dictionary:
	var out := RULES.duplicate()
	out.merge(rules, true)
	return out


# ------------------------------------------------------------ the moment --

## Whether the hero has beaten all five castle wizards (1997's test of the
## defeated bits against 0x3E, dE:1031).
static func all_beaten(player: AdventurePlayer) -> bool:
	return player != null and player.defeated_wizards.size() >= ALL_FIVE


## @CASTLEWIN 6, its lines: the fifth wizard's screen.
static func fifth_lines() -> Array[String]:
	return _lines(FIFTH)


## @CASTLEWIN 7 and 8, the lines under it: the battles so far, [param
## score_so_far] shown no lower than 0 ([method shown]).
static func banish_lines(score_so_far: int) -> Array[String]:
	var out := _lines(BANISH % shown(score_so_far))
	out.append_array(_lines(GOOD_LUCK))
	return out


## @CASTLEWIN 9 and 10: the win's words with the final score [param
## final_years].
static func win_lines(final_years: int) -> Array[String]:
	var out := _lines(PROTECTED % final_years)
	out.append_array(_lines(REJOICE))
	return out


## @QUESTFAILED 1, 4 and 5: the quest failed in the final battle — the
## blank lines kept, as 1997 drew them.
static func failed_lines() -> Array[String]:
	var out := _lines(FAILED)
	out.append_array(_lines(WORN_DOWN))
	out.append_array(_lines(SUFFER))
	return out


# ------------------------------------------------------------- the score --

## THE BATTLES' SHARE OF THE SCORE, in parts: `{sieges, ruled, wins,
## kinds_sum, castle_wizards, base}` — the sieges counted, the towns a
## wizard holds now, the wins in the victory log, their `Σ (kind + 2)`, the
## castle wizards among them, and the base by the formula (the class's
## notes). A win logged with no kind (−1, a save from before part B) is
## counted by the kind its creature's name is, else as kind 0 [ours: 1997's
## log always held a kind].
static func score_parts(player: AdventurePlayer) -> Dictionary:
	var sieges := maxi(player.siege_count, 0)
	var ruled := 0
	if player.world != null:
		for slot in player.world.sites.size():
			if TownStatus.ruled(player.world, slot):
				ruled += 1
	var kinds_sum := 0
	var castle_wizards := 0
	for win in player.duel_victories:
		var kind := victory_kind(win)
		kinds_sum += kind + KIND_STEP
		if kind == CreatureBook.CASTLE_WIZARD:
			castle_wizards += 1
	var base := 2 * (3 * (-sieges - RULED_COST * ruled) + kinds_sum + CASTLE_WIZARD_YEARS * castle_wizards)
	return {"sieges": sieges, "ruled": ruled, "wins": player.duel_victories.size(),
		"kinds_sum": kinds_sum, "castle_wizards": castle_wizards, "base": base}


## The score of the battles so far ([method score_parts]'s base): may be
## below 0.
static func score(player: AdventurePlayer) -> int:
	return int(score_parts(player)["base"])


## The kind of win [param win] (`{color, kind, creature}`): its own, else
## its creature's ([method CreatureBook.row_named]), else 0.
static func victory_kind(win: Variant) -> int:
	if not win is Dictionary:
		return 0
	var kind: Variant = (win as Dictionary).get("kind", -1)
	if (kind is int or kind is float) and int(kind) >= 0:
		return int(kind)
	var row := CreatureBook.row_named(String((win as Dictionary).get("creature", "")))
	return maxi(CreatureBook.kind(row), 0) if row >= 0 else 0


## The score as @CASTLEWIN 7 shows it: no lower than 0.
static func shown(value: int) -> int:
	return maxi(value, 0)


## THE YEARS THE BATTLE ADDS for Arzakon's life going from [param
## life_start] to [param life_end]: under "lives lost" 10 for each life he
## lost (below 0 too while `overkill`, else no more than he began with),
## never fewer than 0; "as played" `(100 − life_end) · 10`, which can be
## below 0.
static func years(life_start: int, life_end: int, rules := {}) -> int:
	var r := rules_with(rules)
	if String(r["years"]) == AS_PLAYED:
		return (AS_PLAYED_START - life_end) * YEARS_A_LIFE
	var lost := maxi(life_start - life_end, 0)
	if not bool(r["overkill"]):
		lost = mini(lost, maxi(life_start, 0))
	return lost * YEARS_A_LIFE


## THE FINAL SCORE: [param base] (floored first under "floored", [method
## shown]) and the battle's [method years].
static func final_score(base: int, life_start: int, life_end: int, rules := {}) -> int:
	var r := rules_with(rules)
	var from := shown(base) if String(r["base"]) == FLOORED else base
	return from + years(life_start, life_end, r)


# ------------------------------------------------------------- the duel --

## THE HERO'S LIFE against Arzakon: a castle duel's — the mana links and the
## next duel's lives ([method CreatureMeeting.hero_life]) — and, only "as
## played", the castle's life pool [param pool].
static func hero_life(player: AdventurePlayer, pool := 0, rules := {}) -> int:
	var r := rules_with(rules)
	return CreatureMeeting.hero_life(player) + (pool if String(r["pool"]) == AS_PLAYED else 0)


## THE FINAL BATTLE THE ENGINE IS HANDED ([DuelConfig]; seat 0 the hero,
## seat 1 Arzakon — the class's notes): his row drawn first on the
## adventure's dice (55 or 56; 0 — 999 draws missed, about once in 10¹⁶ —
## is 55 [ours]), then the hero's deck in use padded on them ([method
## CreatureMeeting.padded_deck]); his maindeck; the lives; no stake either
## side; his two artifacts in play, and the hero's next-duel card; the
## first move the hero's when the world gave it, else 1997's coin; 1997's
## mulligan; the computer at the hero's difficulty; the hero's playmat.
## [param pool] the castle's life pool ([method hero_life]).
static func duel_config(player: AdventurePlayer, pool := 0, rules := {}) -> DuelConfig:
	var r := rules_with(rules)
	var row := draw_row(player)
	var config := DuelConfig.new()
	config.decks = [CreatureMeeting.padded_deck(player, player.deck_cards()), CreatureDeck.for_meeting(row, 0)]
	var foe := ARZAKON_NAME if String(r["name"]) == ARZAKON_NAME else CreatureBook.duel_name(row)
	config.player_names = [player.name if player.name != "" else "Hero", foe]
	var deck_name := player.deck_names[player.current_deck] if player.current_deck < player.deck_names.size() else ""
	config.deck_names = [deck_name if deck_name != "" else "Deck %d" % (player.current_deck + 1),
		CreatureBook.name_of(row)]
	config.portraits = [player.portrait, CreatureBook.face_id(row)]
	config.lives = [hero_life(player, pool, r), CreatureBook.duel_life(row, player.difficulty)]
	config.pilots = [null, CreatureMeeting.ai_for(player.difficulty)]
	# [ours: 1997 slip C3-4] No stake either side.
	config.ante_cards = [[], []]
	config.ante_extras = [[], []]
	if player.next_duel_first_move:
		config.first_player = 0
	var hero_in_play: Array = []
	if player.next_duel_card != "":
		hero_in_play.append(player.next_duel_card)
	var arzakon_in_play: Array = []
	arzakon_in_play.append_array(IN_PLAY)
	config.start_in_play = [hero_in_play, arzakon_in_play]
	config.mulligan_rule = MtgGame.MULLIGAN_1997
	config.ai_random_play_or_draw = true
	config.pace = Settings.ai_pace()
	config.rng_seed = randi() | 1
	config.apply_deck_colors()
	CreatureMeeting.hero_playmat(config, player)
	return config


## ARZAKON'S ROW drawn on the adventure's dice ([method CreatureBook.pick]
## with any colour and tier 100: 55 or 56), the dice given back; the lair
## row 1997 would read after 999 misses is 55 here.
static func draw_row(player: AdventurePlayer) -> int:
	var dice := MsvcRandom.new(player.dice)
	var row := CreatureBook.pick(dice, 0, TIER)
	player.dice = dice.state
	return row if CreatureBook.kind(row) == CreatureBook.ARZAKON else ROW


# --------------------------------------------------------------- the door --

## THE HERO AT ARZAKON'S DOOR, the battle beginning (the finale calls it
## as the hero leaves the deck builder for the battle, just before the duel
## is dealt — so leaving the builder is no battle begun): [member
## AdventurePlayer.at_door] set, and the portal stood ([method open_portal])
## when none stands yet (so an adventure taken up again at the door has its
## portal on the world). True when the adventure is to be saved now — under
## both rules: "Reload allowed"'s checkpoint, and under "One life" the
## battle begun, also marked [constant HallOfFame.BEGUN] in the Hall's file
## at [param hall_path] ([member HallOfFame.file] when "") so no older save
## can fight it again (the class's notes). False for an adventure ended.
static func door(player: AdventurePlayer, hall_path := "") -> bool:
	if player.ended != "":
		return false
	player.at_door = true
	if player.portal.is_empty():
		# Silently: the hero who faces him at once never saw it (the
		# owner's ruling of 2026-10-28).
		open_portal(player, false)
	if player.life_rule == AdventurePlayer.LIFE_ONE:
		HallOfFame.mark_one_life(player.adventure_id, HallOfFame.BEGUN, hall_path)
	return true


## ARZAKON'S PORTAL STANDS on the world, open (the owner's Q-PORTAL,
## "Return to Shandalar first"), on [method portal_tile] — with no free land
## at all, on the fifth castle's ruins, else the hero's tile — and, [param
## told], the journal says where ([constant OPENED_LOG], [method
## tell_portal]). A portal already standing is kept as it is (a save from
## before the middle of the map keeps it on the ruins). The portal ([member
## AdventurePlayer.portal], `{x, y, state}`).
static func open_portal(player: AdventurePlayer, told := true) -> Dictionary:
	if not player.portal.is_empty():
		return player.portal
	var at := portal_tile(player.world) if player.world != null else Vector2i(-1, -1)
	if at.x < 0:
		at = player.tile()
		var castle := fifth_castle(player)
		if castle >= 0:
			var slot: Dictionary = player.world.encounters[castle]
			at = Vector2i(int(slot.get("x", at.x)), int(slot.get("y", at.y)))
	player.portal = {"x": at.x, "y": at.y, "state": PORTAL_OPEN}
	if told:
		tell_portal(player)
	return player.portal


## THE JOURNAL SAYS THE PORTAL OPENED — "Arzakon's Portal opened in the
## middle of Shandalar, east of Kraag Temple", pinned to it — once: the
## line, or "" when no open portal stands or the journal says so already.
static func tell_portal(player: AdventurePlayer) -> String:
	if player == null or String(player.portal.get("state", "")) != PORTAL_OPEN or portal_told(player):
		return ""
	var line := OPENED_LOG % portal_where(player)
	_log_at_portal(player, "portal", line)
	return line


## Whether the journal already says the portal opened ([method tell_portal]).
static func portal_told(player: AdventurePlayer) -> bool:
	var opened := OPENED_LOG.get_slice("%", 0)
	for entry in player.journal:
		if entry is Dictionary and String((entry as Dictionary).get("event", "")) == "portal" \
				and String((entry as Dictionary).get("text", "")).begins_with(opened):
			return true
	return false


## THE HERO TURNS BACK FROM ARZAKON'S DOOR (the owner's ruling of
## 2026-10-28, "Fight or return"; the class's notes): under "Reload
## allowed", the adventure going on and the hero at the door — no longer
## at it ([member AdventurePlayer.at_door]: a reload opens on the world),
## the portal standing open (stood first when none stands) and the journal
## told where, once. The journal's line when it is written now, else "";
## nothing changes for a hero not at the door, an adventure ended or one of
## "One life" (whose door means the battle has begun).
static func leave_door(player: AdventurePlayer) -> String:
	if player == null or not player.at_door or player.ended != "" \
			or player.life_rule == AdventurePlayer.LIFE_ONE:
		return ""
	player.at_door = false
	open_portal(player, false)
	return tell_portal(player)


## WHERE THE PORTAL STANDS in [param world] (the class's notes): the free
## land tile nearest the map's middle that the hero can walk to from the
## castles — searched outward over the whole map —; else (no free land the
## hero can reach) the nearest free land at all; (−1, −1) when there is
## none. Nearest by the straight distance from the middle (31.5, 31.5), on
## a tie the upper row, then the left tile — no dice.
static func portal_tile(world: ShandalarWorld) -> Vector2i:
	var reach := reachable(world)
	# Each tile's key: its distance from the middle, then its row, then its
	# column — sorted, the order of the search.
	var order := PackedInt64Array()
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			order.append(_from_middle(Vector2i(x, y)) * 4096 + y * ShandalarWorld.TILES + x)
	order.sort()
	var reached := Vector2i(-1, -1)
	var anywhere := Vector2i(-1, -1)
	for key in order:
		var tile := Vector2i(key % ShandalarWorld.TILES, (key / ShandalarWorld.TILES) % ShandalarWorld.TILES)
		if not portal_may_stand(world, tile):
			continue
		if anywhere.x < 0:
			anywhere = tile
		if reach[tile.y * ShandalarWorld.TILES + tile.x] != 0:
			reached = tile
			break
	return reached if reached.x >= 0 else anywhere


## Whether the portal may stand on [param tile]: land, with no site (a
## castle is one), no road and no dungeon.
static func portal_may_stand(world: ShandalarWorld, tile: Vector2i) -> bool:
	if not world.is_land(tile.x, tile.y):
		return false
	var taken := ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON
	return world.tile_flags(tile.x, tile.y) & taken == 0


## THE LAND THE HERO CAN WALK TO from the castles (encounter slots 0–4; the
## world's start when none stands on land), by the walk's rule ([HeroWalk]:
## any land, the eight ways, the sea and the map's edge walls): a byte per
## tile, row by row, 1 where the hero can go.
static func reachable(world: ShandalarWorld) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(ShandalarWorld.TILES * ShandalarWorld.TILES)
	var todo: Array[Vector2i] = []
	for i in mini(world.encounters.size(), DungeonDoors.CASTLES):
		var slot: Dictionary = world.encounters[i]
		todo.append(Vector2i(int(slot.get("x", -1)), int(slot.get("y", -1))))
	todo.append(world.start_tile())
	var sources := todo.duplicate()
	todo.clear()
	for tile in sources:
		if _on_map(tile) and world.is_land(tile.x, tile.y) and seen[tile.y * ShandalarWorld.TILES + tile.x] == 0:
			seen[tile.y * ShandalarWorld.TILES + tile.x] = 1
			todo.append(tile)
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for d in range(1, 9):
			var next := at + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
			if _on_map(next) and seen[next.y * ShandalarWorld.TILES + next.x] == 0 \
					and world.is_land(next.x, next.y):
				seen[next.y * ShandalarWorld.TILES + next.x] = 1
				todo.append(next)
	return seen


## The portal's tile, (−1, −1) when none stands.
static func portal_tile_of(player: AdventurePlayer) -> Vector2i:
	if player == null or player.portal.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(player.portal["x"]), int(player.portal["y"]))


## WHERE IT STANDS, in words: "in the middle of Shandalar, east of Kraag
## Temple" — the middle named within [constant MIDDLE_WORDS] tiles of it,
## then the way from the nearest town, village or city (the directions of
## the quests and the wise men, [method WorldNames.direction]); "" when no
## portal stands.
static func portal_where(player: AdventurePlayer) -> String:
	var at := portal_tile_of(player)
	if at.x < 0 or player.world == null:
		return ""
	var parts: Array[String] = []
	if _from_middle(at) <= (2 * MIDDLE_WORDS) * (2 * MIDDLE_WORDS):
		parts.append(IN_THE_MIDDLE)
	var near := portal_near(player)
	if near != "":
		parts.append(near)
	return ", ".join(parts) if not parts.is_empty() else SOMEWHERE


## "east of Kraag Temple": the way to the portal from the town, village or
## city nearest it; "" for none.
static func portal_near(player: AdventurePlayer) -> String:
	var at := portal_tile_of(player)
	var town := _nearest_town(player.world, at) if at.x >= 0 and player.world != null else -1
	if town < 0:
		return ""
	var site: Dictionary = player.world.sites[town]
	var from := Vector2i(int(site["x"]), int(site["y"]))
	return OF_TOWN % [WorldNames.direction(from, at).to_lower(), WorldNames.site_name(player.world, town)]


## THE GUIDE ARROWS' MARK for the portal ([method WorldStatus.targets]):
## `{tile, kind, name}` — "portal" while it is open and the adventure goes
## on, "monument" once petrified; `{}` otherwise.
static func portal_target(player: AdventurePlayer) -> Dictionary:
	if player == null or player.portal.is_empty() or player.ended == AdventurePlayer.ENDED_FAILED:
		return {}
	var state := String(player.portal.get("state", ""))
	if state == PORTAL_OPEN and player.ended == "":
		return {"tile": portal_tile_of(player), "kind": PORTAL_KIND, "name": PORTAL_NAME}
	if state == PORTAL_PETRIFIED:
		return {"tile": portal_tile_of(player), "kind": MONUMENT_KIND, "name": MONUMENT_NAME}
	return {}


## THE QUEST PANE'S LINE for the portal ([method WorldStatus.lines]):
## "Arzakon's Portal: east of Kraag Temple" while open, "Petrified Portal:
## east of Kraag Temple" after the win; "" when it shows none.
static func portal_line(player: AdventurePlayer) -> String:
	var mark := portal_target(player)
	if mark.is_empty():
		return ""
	var near := portal_near(player)
	if near == "":
		near = IN_THE_MIDDLE if _from_middle(portal_tile_of(player)) <= (2 * MIDDLE_WORDS) * (2 * MIDDLE_WORDS) \
			else SOMEWHERE
	return (OPEN_LINE if String(mark["kind"]) == PORTAL_KIND else PETRIFIED_LINE) % near


## THE HERO WALKS ON after the win (the owner: "The win also gives you the
## choice to end or return to roam Shandalar"; the finale's [constant
## WIN_ROAM]): the portal the petrified monument — always, stood first when
## none stands (part C stage C3, h5-6: one left open by a damaged save was
## kept open, an open portal after the win) — and the journal's line,
## "Arzakon's Portal turned to stone in the middle of Shandalar, east of
## Kraag Temple", pinned to the monument — once ([member
## AdventurePlayer.final]'s `roamed`). The line, or "" for an adventure not
## won or a line already written.
static func roam(player: AdventurePlayer) -> String:
	if player == null or player.ended != AdventurePlayer.ENDED_WON:
		return ""
	if player.portal.is_empty():
		open_portal(player, false)
	player.portal["state"] = PORTAL_PETRIFIED
	if bool(player.final.get("roamed", false)):
		return ""
	var line := PETRIFIED_LOG % portal_where(player)
	_log_at_portal(player, "portal", line)
	player.final["roamed"] = true
	return line


## A journal line [param text] of [param event] pinned to the portal's tile
## (its middle, in world units), so the journal's map points there.
static func _log_at_portal(player: AdventurePlayer, event: String, text: String) -> void:
	var before := player.journal.size()
	player.log_event(event, text)
	var at := portal_tile_of(player)
	if player.journal.size() > before and at.x >= 0:
		var line: Dictionary = player.journal.back()
		line["x"] = at.x * 32 + 16
		line["y"] = at.y * 32 + 16


## The town, village or city nearest [param tile] (the straight distance,
## the lower slot on a tie), −1 for none.
static func _nearest_town(world: ShandalarWorld, tile: Vector2i) -> int:
	var best := -1
	var best_distance := 1 << 30
	for slot in world.sites.size():
		var kind := int(world.sites[slot]["type"])
		if kind < ShandalarWorld.VILLAGE or kind > ShandalarWorld.CITY:
			continue
		var dx := int(world.sites[slot]["x"]) - tile.x
		var dy := int(world.sites[slot]["y"]) - tile.y
		if dx * dx + dy * dy < best_distance:
			best_distance = dx * dx + dy * dy
			best = slot
	return best


## Twice a tile's distance from the map's middle, squared: `(2x − 63)² +
## (2y − 63)²` (whole numbers).
static func _from_middle(tile: Vector2i) -> int:
	var dx := 2 * tile.x - (ShandalarWorld.TILES - 1)
	var dy := 2 * tile.y - (ShandalarWorld.TILES - 1)
	return dx * dx + dy * dy


static func _on_map(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < ShandalarWorld.TILES and tile.y < ShandalarWorld.TILES


## The castle slot (0 black … 4 white) of the wizard beaten last, −1 for
## none ([member AdventurePlayer.defeated_wizards] in the order they fell).
static func fifth_castle(player: AdventurePlayer) -> int:
	if player == null or player.world == null or player.defeated_wizards.is_empty():
		return -1
	var castle := AdventurePlayer.COLORS.find(player.defeated_wizards.back())
	return castle if castle >= 0 and castle < mini(player.world.encounters.size(), DungeonDoors.CASTLES) else -1


## Whether Arzakon's portal stands on [param tile] (open or petrified).
static func portal_at(player: AdventurePlayer, tile: Vector2i) -> bool:
	return player != null and not player.portal.is_empty() and portal_tile_of(player) == tile


## Whether the hero may enter the portal: open, Arzakon not yet beaten.
static func portal_open(player: AdventurePlayer) -> bool:
	return player != null and String(player.portal.get("state", "")) == PORTAL_OPEN and player.ended == ""


## The portal's name on the world: open or petrified, "" for none.
static func portal_name(player: AdventurePlayer) -> String:
	match String(player.portal.get("state", "")):
		PORTAL_OPEN:
			return PORTAL_NAME
		PORTAL_PETRIFIED:
			return MONUMENT_NAME
	return ""


# ------------------------------------------------------------- the result --

## THE FINAL BATTLE SETTLED from its [param report] ([signal
## WorldDuels.ended]; [param conceded] when the hero conceded, a report
## unfinished or none a draw): what it leaves — `{result, won, outcome,
## reload, lives_start, lives_end, base, shown, years, score, journal}` —
## the duel's 1997 result (1, 0, −1), whether it is a win, "won" or
## "failed", whether the adventure waits at the door ("Reload allowed"
## after a loss), the lives `[hero, Arzakon]`, the battles' base, as shown,
## the battle's years and the final score (0 unless won).
## Written to the hero, as the class's notes say:
##  - the journal, "Defeated an Arzakon" or "Lost to an Arzakon" (1997's
##    line for row 55, `@LOGSTRINGS` 4/5; a draw or a concession lost too —
##    as played, "Defeated" whatever came); never the victory log (1997
##    logged only the world's meetings, E:2264);
##  - the next duel's gifts spent (as after any duel);
##  - a win: [member AdventurePlayer.ended] "won", [member
##    AdventurePlayer.final], the door left, the portal petrified (stood
##    first, [method open_portal], when none stands);
##  - a loss under "Reload allowed": one more attempt lost, the hero kept at
##    the door; under "One life": ended "failed", the end's record;
##  - under "One life", the adventure's mark in the Hall's file at [param
##    hall_path]: "failed" at a loss, taken away at a win (the class's
##    notes) — the one file this writes.
## The save is not written here: the finale saves (and writes the
## [HallOfFame] line, [method HallOfFame.add]) at once, before the movie.
## [param when] the moment (ISO, UTC) for the record — now when "".
static func settle(player: AdventurePlayer, report: DuelReport, conceded := false, rules := {},
		when := "", hall_path := "") -> Dictionary:
	var r := rules_with(rules)
	var result := DuelReport.LOSS
	if report != null and not conceded:
		result = report.result if report.finished else DuelReport.DRAW
	var lives_start := [0, 0]
	var lives_end := [0, 0]
	if report != null:
		lives_start = [report.lives_start[0], report.lives_start[1]]
		lives_end = [report.lives_end[0], report.lives_end[1]]
	var won := result == DuelReport.WIN or String(r["result"]) == AS_PLAYED
	# 1997 wrote row 55 whichever row was drawn (`0xB7`, dE:1064).
	var row := ROW
	var base := score(player)
	var out := {"result": result, "won": won, "outcome": WON if won else FAILED_END, "reload": false,
		"lives_start": lives_start, "lives_end": lives_end, "base": base, "shown": shown(base),
		"years": 0, "score": 0, "journal": ""}
	player.clear_duel_gifts()
	if won:
		# The portal he came through, stood first (silently) when none
		# stands.
		open_portal(player, false)
		out["journal"] = DuelSpoils.DEFEATED % CreatureBook.called(row)
		player.log_event("duel", out["journal"], {"won": true, "creature": CreatureBook.name_of(row),
			"row": row, "color": 0, "final": true})
		out["years"] = years(int(lives_start[1]), int(lives_end[1]), r)
		out["score"] = final_score(base, int(lives_start[1]), int(lives_end[1]), r)
		player.ended = AdventurePlayer.ENDED_WON
		player.at_door = false
		player.final = _record(player, WON, out, when)
		player.portal["state"] = PORTAL_PETRIFIED
		if player.life_rule == AdventurePlayer.LIFE_ONE:
			HallOfFame.mark_one_life(player.adventure_id, "", hall_path)
		return out
	out["journal"] = DuelSpoils.LOST_TO % CreatureBook.called(row)
	player.log_event("duel", out["journal"], {"won": false, "creature": CreatureBook.name_of(row),
		"row": row, "color": 0, "final": true, "draw": result == DuelReport.DRAW})
	if player.life_rule == AdventurePlayer.LIFE_ONE:
		player.ended = AdventurePlayer.ENDED_FAILED
		player.at_door = false
		player.final = _record(player, FAILED_END, out, when)
		HallOfFame.mark_one_life(player.adventure_id, HallOfFame.FAILED, hall_path)
	else:
		player.final_attempts += 1
		player.at_door = true
		out["reload"] = true
	return out


## AN ADVENTURE TAKEN UP AGAIN (the load calls it before the world opens):
## under "One life", an adventure not ended whose save stands at the door
## (a game closed or left in the battle), or whose mark in the Hall's file
## at [param hall_path] says its battle began or was lost (a save from
## before the door), is a LOST FINAL BATTLE — settled with no report
## ([method settle]: "Lost to an Arzakon", the gifts spent, ended "failed",
## the end's record with the attempts as they were and `left` true), and
## true comes back: the caller saves it and opens the quest-failed end.
## False, and nothing changed, otherwise — always under "Reload allowed".
## The owner's ruling, the class's notes. [param when] as [method settle]'s.
static func on_load(player: AdventurePlayer, hall_path := "", when := "") -> bool:
	if player == null or player.life_rule != AdventurePlayer.LIFE_ONE or player.ended != "":
		return false
	var mark := HallOfFame.one_life_state(player.adventure_id, hall_path)
	if not player.at_door and not mark in HallOfFame.ONE_LIFE_STATES:
		return false
	settle(player, null, true, {}, when, hall_path)
	player.final["left"] = true
	return true


## The end's record ([member AdventurePlayer.final]) of [param outcome]
## from the settled battle [param settled].
static func _record(player: AdventurePlayer, outcome: String, settled: Dictionary, when: String) -> Dictionary:
	var out := {"result": outcome, "base": int(settled["base"]), "years": int(settled["years"]),
		"lives_start": settled["lives_start"], "lives_end": settled["lives_end"],
		"difficulty": player.difficulty, "days": player.quest_timer / WorldStatus.DAY,
		"wins": int(player.duel_record()["won"]), "attempts": player.final_attempts,
		"date": when if when != "" else Time.get_datetime_string_from_system(true) + "Z",
		"life_rule": player.life_rule}
	if outcome == WON:
		out["score"] = int(settled["score"])
	return out


## 1997's words broken at their `\n`, the one that ends them dropped.
static func _lines(text: String) -> Array[String]:
	var out: Array[String] = []
	for line in text.trim_suffix("\n").split("\n"):
		out.append(line)
	return out

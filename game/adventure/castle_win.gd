class_name CastleWin
extends RefCounted
## A WIZARD BEATEN IN HIS CASTLE (part C, 2026-10-27) — 1.3's
## `HandleDefeatedWizardCastle(index)` (dungeonEncounter.c 918–1108, the
## "dE" lines below; retail database.c 1594–1780, the same), called by the
## board as the castle's wizard's duel is won ([DungeonDuels]: outcome
## `beaten`), headless: what the win changes in the adventure ([method beat])
## and the three cards the hero picks ([method offered], [method take]).
## The pane — his room's still, the words over the trade backdrop
## (`Tradscrn.pic`) with his castle's tune, the picks in the card browser,
## the freed towns' news line — is stage C2's; the fifth wizard's sequence
## and Arzakon are [FinalBattle]'s, handed over with `all_five`.
##
## [method beat], IN 1997'S ORDER:
##  - THE JOURNAL: "Defeated a Greater Lich" (`@LOGSTRINGS` 4; 1997's type 2,
##    `((g_castle_defeat_music_ids[index] + 1) · 7) | 0x80` with `{0, 2, 3,
##    4, 1}`, dE:936 — the castle rows 7, 21, 28, 35, 14, [constant
##    CreatureBook.CASTLE_ROWS]), a win in the record and on the creatures'
##    page;
##  - THE VICTORY LOGGED [ours: 1997 slip — the owner's ruling SC2 of
##    2026-10-27]: the castle's wizard's win, kind 12, on his colour
##    ([method AdventurePlayer.log_victory]) — it counts in the wins
##    ([method AdventurePlayer.total_wins]) and pays the end score's +25 a
##    castle wizard 1997 designed and never paid (its score counted only the
##    log, which only world meetings wrote; unused-features §27). Room wins
##    stay out of the log, as played;
##  - 1997's wizards' window (`ShowStatsWindow(1, colour)`, dE:937) is not
##    shown: the owner's ruling B-3/B-4, it never opens by itself (F6 and the
##    hero pane's Wizards tab hold it);
##  - THE WORDS (dE:943–960): `@CASTLEWIN` 0/1 by the wizard's gender —
##    "You have defeated the dreaded / Red Wizardess.  No longer shall / her
##    evil creatures oppress / the good people of Shandalar." (two spaces
##    after the full stop, as written) — then, for every town he rules, in
##    slot order, "<town> freed!" (2): the town FREED, its mana link still
##    lost, no "Freed %s" journal line (as played) — [ours, the owner's
##    ruling of 2026-10-29] under the sieges' paces Steady, Rare and None a
##    link a siege took comes back ([method Sieges.free_all]): "<town>
##    freed!", then "Its mana link is restored." ([constant LINK_BACK]) and a
##    journal line ([constant LINK_LOG]);
##  - HIS CREATURES LEAVE (dE:965–972): every lair and creature of his
##    colour on the map, the besieger too — its siege over [ours: 1997 left
##    the flag up for the clock] ([method Sieges.free_all]); later spawns
##    skip a beaten colour ([WorldLairs]);
##  - THE DEFEATED COLOUR ([member AdventurePlayer.defeated_wizards],
##    dE:961);
##  - THE CASTLE A BEATEN SITE, type 5 (`FindTownAtWorldCoordinates` of the
##    castle slot's tile, dE:962–964): the world draws its beaten frame
##    ([WorldView]), its pane says so ([VisitPane]), no siege scores it
##    ([method Sieges.candidates], [method Sieges.castle_tiles]);
##  - THE PICKS' WORDS: "You may take any three / different Red cards."
##    (`@CASTLEWIN` 3 with `@COLORCARDS`).
## Then the hero picks THREE CARDS (dE:983–1017): the card browser (the
## trades' — [CardTradePane]) titled "Pick a card - 3 left" (`@CASTLEWIN` 4)
## with the colour's chip set and no Done; a card chosen asks "Will you take
## this card... / Yes / No" (5); Yes, it joins the hero's cards IN NO DECK
## ([method take]), No asks again; no way to skip. "Different" holds within
## the three: a card taken is not offered again ([method offered]); a card
## already owned may be taken. Then, not all five beaten, the tune stops and
## the hero is back on the world (the board left, no retaliation: he is
## beaten — [DungeonDoors]); all five, [FinalBattle]'s sequence.
##
## Ours beside: the cards offered follow the hero's card rule as every
## source does (under the Classic MTG rules no card held at its limit,
## [method CardShop.classic_allows]); a full bag is said ([constant
## AdventurePlayer.BAG_FULL]; 1997 lost the card without a word); a second
## call for a wizard already beaten changes nothing.
##
## DESIGNED, NEVER USED (dead in 1997, dead here): the defeated bit cleared
## during the picks and set again after (dE:981, 1024) — no reader runs
## meanwhile; "Defeated %1 (%2)" (`@LOGSTRINGS` 7, unused-features §31) —
## never written (to switch on: a second journal line here).

## `@CASTLEWIN` (Advstrings.txt; 0-based): 0 her (the Blue and the Red
## Wizardess), 1 his.
const DEFEATED_HER := "You have defeated the dreaded\n%s.  No longer shall\nher evil creatures oppress\nthe good people of Shandalar.\n"
const DEFEATED_HIS := "You have defeated the dreaded\n%s.  No longer shall\nhis evil creatures oppress\nthe good people of Shandalar.\n"
## 2, after each town's name.
const FREED := " freed!\n"
## A freed town whose link came back [ours]: its line and its journal line.
const LINK_BACK := " freed!\nIts mana link is restored.\n"
const LINK_LOG := "Mana link restored at %s"
## 3, with `@COLORCARDS` ([constant WorldClues.COLOR_CARDS]).
const TAKE_THREE := "You may take any three\ndifferent %s.\n"
## 4, the browser's title.
const PICK_LEFT := "Pick a card - %d left"
## 5: `Will you take this card...\n    Yes\n    No\n` — the question and
## its two answers.
const TAKE_THIS := "Will you take this card..."
const YES := "Yes"
const NO := "No"
## The cards picked.
const PICKS := 3
## A beaten castle's site type ([constant Sieges.BEATEN_CASTLE]).
const BEATEN_CASTLE := Sieges.BEATEN_CASTLE
## The wizards there are.
const WIZARDS := 5
## The castle's tune under the words and the picks (`PlayCastleMusic`,
## dE:942): `music_castle_<colour>`.
const MUSIC := "music_castle_%s"


## THE WIZARD OF CASTLE [param index] (0–4: black, blue, green, red, white)
## BEATEN — the class doc's steps, in 1997's order: `{index, color, wizard,
## row, journal, towns, restored, lines, take_words, music, all_five,
## already}` — `towns` the sites freed (slot order), `restored` the names of
## those whose link came back (0.50.65), `lines` the words a line each (the
## defeated words, then "<town> freed!" each), `take_words` the picks' line,
## `all_five` every wizard now beaten (the hand-off to [FinalBattle]).
## `already` true, and nothing changed, for a wizard beaten before. `{}` for
## no such castle.
static func beat(player: AdventurePlayer, index: int) -> Dictionary:
	if player == null or index < 0 or index >= WIZARDS:
		return {}
	var color := index + 1
	var hue: String = AdventurePlayer.COLORS[index]
	var row := CreatureBook.castle_row(color)
	var out := {"index": index, "color": color, "wizard": WorldNames.WIZARDS[index], "row": row,
		"journal": "", "towns": [] as Array[int], "restored": [] as Array[String], "lines": [] as Array[String],
		"take_words": TAKE_THREE % WorldClues.COLOR_CARDS[color], "music": MUSIC % hue,
		"all_five": false, "already": hue in player.defeated_wizards}
	if bool(out["already"]):
		out["lines"] = defeated_lines(color, [] as Array[String])
		out["all_five"] = all_five(player)
		return out
	out["journal"] = DuelSpoils.DEFEATED % CreatureBook.called(row)
	player.log_event("duel", out["journal"], {"won": true, "creature": CreatureBook.name_of(row),
		"row": row, "color": color, "castle": index})
	player.log_victory(row, color)
	var freed: Array[int] = []
	if player.world != null:
		freed = Sieges.free_all(player, color)
	out["towns"] = freed
	player.defeated_wizards.append(hue)
	var site := castle_site(player.world, index)
	if site >= 0:
		player.world.sites[site]["type"] = BEATEN_CASTLE
	var names: Array[String] = []
	var restored: Array[String] = []
	for town in freed:
		var called := WorldNames.site_name(player.world, town)
		names.append(called)
		# A ruled town is never linked: a freed one linked now got its link
		# back ([method AdventurePlayer.restore_link]).
		if TownStatus.linked(player.world, town):
			restored.append(called)
			player.log_event("link", LINK_LOG % called, {"town": town})
	out["restored"] = restored
	out["lines"] = defeated_lines(color, names, restored)
	out["all_five"] = all_five(player)
	return out


## THE WORDS over the trade backdrop (`@CASTLEWIN` 0/1, then 2 for each
## town in [param towns]), a line each as 1997 broke them — a town of
## [param restored] with its link's words ([constant LINK_BACK]).
static func defeated_lines(color: int, towns: Array[String], restored: Array[String] = []) -> Array[String]:
	var c := clampi(color, 1, 5)
	var text := (DEFEATED_HER if CreatureMeeting.wizard_feminine(c) else DEFEATED_HIS) % WorldNames.WIZARDS[c - 1]
	for town in towns:
		text += town + (LINK_BACK if town in restored else FREED)
	return CreatureMeeting.lines_of(text)


## Whether all five wizards are beaten.
static func all_five(player: AdventurePlayer) -> bool:
	for hue in AdventurePlayer.COLORS:
		if not hue in player.defeated_wizards:
			return false
	return true


## The site of castle [param index] (the site standing on the castle slot's
## tile, `FindTownAtWorldCoordinates`), −1 for none.
static func castle_site(world: ShandalarWorld, index: int) -> int:
	if world == null or index < 0 or index >= mini(world.encounters.size(), WIZARDS):
		return -1
	var castle: Dictionary = world.encounters[index]
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		if int(site["x"]) == int(castle.get("x", -1)) and int(site["y"]) == int(castle.get("y", -1)) \
				and int(site["type"]) > 0:
			return slot
	return -1


## The browser's title with [param left] cards still to pick:
## "Pick a card - 3 left".
static func pick_title(left: int) -> String:
	return PICK_LEFT % left


## THE CARDS OFFERED for a pick after beating the wizard of colour
## [param color] (1 black … 5 white), the cards [param taken] already this
## time left out: every card a trade may offer ([method CardTrade.catalogue])
## of that colour, as the browser's colour chip reads it (`1 << colour`,
## [method CardTrade.wanted]: a gold card of it too), and — the hero's card
## rule, as every source — none held at its limit under the Classic MTG
## rules. By name, in the catalogue's order.
static func offered(player: AdventurePlayer, taken: Array, color: int) -> Array[String]:
	var out: Array[String] = []
	var bit := 1 << clampi(color, 1, 5)
	var rule := CardShop.classic_rule(player)
	for row in CardTrade.catalogue():
		var card_name := String(row["name"])
		if card_name in taken or not CardTrade.wanted(bit, row["facts"]):
			continue
		if not CardShop.classic_allows(rule, card_name):
			continue
		out.append(card_name)
	return out


## A PICK TAKEN ("Yes"): card [param card_name] joins the hero's cards in
## no deck ([method AdventurePlayer.add_card]: "Acquired spell" for a rare).
## `{kept, said}` — `kept` false when the full bag could not hold it
## [ours: said; 1997 lost it silently]; the pick is spent either way, as
## 1997's.
static func take(player: AdventurePlayer, card_name: String) -> Dictionary:
	if player == null or card_name == "":
		return {"kept": false, "said": ""}
	if player.add_card(card_name):
		return {"kept": true, "said": "%s joins your cards." % card_name}
	return {"kept": false, "said": AdventurePlayer.BAG_FULL}

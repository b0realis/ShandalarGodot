class_name WorldStatus
extends RefCounted
## WHAT CALLS THE HERO, read from the adventure: the quest under way, a
## town under siege, the wizards' mana taps and the next duel's bonus —
## what the 1997 frame's quest panel (`DrawAdventureQuestStatusPanel`,
## 0054baaa in 1.3) and the wizards' window (F6, `Statwin.dll`) showed,
## in the 1997 words (`Advstrings.txt` `@QUESTSTATUS`, `@NEWSFLASH`).
##
## THE QUEST ([member AdventurePlayer.quest], its fields and rules in
## [Quests]): the panel says what to do and where — "Go East to Kraag
## Temple" while the hero has not turned off the way they set out, then
## "Take letter to …", "Take card to …" or, for a card quest whose card the
## hero does not yet hold, "Find a black Creature spell" — and ours beside
## it, the reward and the days left.
##  - A DAY is 16 steps of the quest clock (a letter's 32 time units are
##    "4 days"); the panel's days left are `(deadline − timer) / 16 + 1`.
##
## THE SIEGE: the creature a wizard sends to a city stands in roaming slot
## 7 (`StartWizardTownSiege`, 005616f9); the panel says "%1 attacking %2!".
## A city the wizard takes is his: its status's high byte holds his colour
## (`ResolveWizardTownSiege`, 00562169), a "mana tap". A wizard who taps
## [constant DOMINION] cities — [constant DOMINION_WITH_RING] with Ring of
## the Guardian — casts the Spell of Dominion and the adventure is lost.
## The sieges themselves are [Sieges]'; the besieger is met and dueled as
## any creature ([WorldCreatures]).
##
## THE GUIDES ([method targets]): the town under siege, and the quest's
## target — none for a creature's quest until its creature is beaten (as
## 1997: the creature comes to the hero, where it will), then its giver.
##
## THE WIZARDS' RECORD ([method wizard_rows]) — what 1997's wizards' window
## (F6, `Statwin.dll`) was handed: `ShowStatsWindow` (1.3
## adventureStats.c 1683–1789) fills one block, `StatWinData`, per wizard
## — his towns, the hero's wins against his colour and his STAFF, a column
## of thirty lights that the wins drain — and Statwin drew it as a picture
## with no words ([WizardsPicture]). The hero pane's Wizards tab reads it
## ([HeroStats]): the picture, and under it the wizard's life in his
## stronghold, the mana domes he controls and the wins against him, in the
## wise man's own phrasing (`Advblocks.txt`, `_qQuote` 0 and 1).
##  - THE FORMULA (aS:1736–1738), d the difficulty 0–3: `required = 30 +
##    5d + d·towns`, `X = max(5d + 20, required − wins)`, `staff = 30 −
##    (required − X)`. X is the wizard's duel life ([method
##    WiseMan.castle_life], the same number); the staff is `30 − min(wins,
##    10 + d·towns)` — full with no wins, whatever his towns, and no lower
##    than the life's floor lets it fall.
##  - A BEATEN WIZARD's staff is 0 and he is not drawn (aS:1717–1720:
##    `progress = 0`). [Ours: 1997 slip — his wins were no longer sent, so
##    his skulls stayed at the last count the window saw, and read 0 after a
##    restart; here they are always his true wins.]
##  - His GEMS are his towns, at most five pieces (`town_count & 0x1f`,
##    five drawn, Statwin main.cpp 2321, 2871); his SKULLS the hero's wins
##    in the steps of `duel_wins_to_skull_index` (main.cpp 2720): none,
##    1–4, 5 for 5–7, 8 for 8–11, 12 for twelve or more.
##  - The wins are those of the victory log against creatures met as his
##    colour ([method AdventurePlayer.wins_over_color], 1997's log byte
##    `colour·16 + kind`): a two-colour creature counts for the colour it
##    was met as.

## Steps of the quest clock in a day.
const DAY := 16
const DOMINION := 3
const DOMINION_WITH_RING := 5
## The lights of a wizard's staff (1997's `progress` out of `0x1e`).
const STAFF := 30
## The skull pictures' steps (`1skulls` … `12skulls.bmp`), by the least wins
## each stands for.
const SKULL_STEPS: Array[int] = [1, 2, 3, 4, 5, 8, 12]
## `@QUESTSTATUS`'s "Go North to"… by the destination's quarter: the
## original's four directions are the screen's diagonals.
const GO: Array[String] = ["Go North to %s", "Go East to %s", "Go South to %s", "Go West to %s"]


## Days on the road: the quest clock, which steps on every 32 ticks the
## hero walks, in the quest's own days [QoL] (1997 counted no days).
static func days_on_road(player: AdventurePlayer) -> int:
	return player.quest_timer / DAY


## Whether a quest is under way.
static func has_quest(player: AdventurePlayer) -> bool:
	return Quests.has_quest(player)


## The quest's days left: `(deadline − timer) / 16 + 1`, at least 0.
static func days_left(player: AdventurePlayer) -> int:
	if not has_quest(player):
		return 0
	var left := int(player.quest.get("deadline", 0)) - player.quest_timer
	return maxi(left / DAY + 1, 0) if left > 0 else 0


## The site the quest sends the hero to, or -1: the giver when its
## creature is beaten; none while a creature's quest waits for its
## creature (the lead's default, as 1997: no way to it is shown — it comes
## to the hero); the destination otherwise.
static func quest_target(player: AdventurePlayer) -> int:
	if not has_quest(player):
		return -1
	var kind := int(player.quest.get("type", 0))
	if kind < Quests.DEFEATED:
		return int(player.quest.get("giver", player.quest.get("destination", -1)))
	if kind < 0:
		return -1
	return int(player.quest.get("destination", -1))


## The quest's lines, as the 1997 panel words them: what to do and where,
## then ours — the reward and the days left.
static func quest_lines(player: AdventurePlayer) -> Array[String]:
	var lines: Array[String] = []
	if not has_quest(player):
		return lines
	var quest := player.quest
	var kind := int(quest.get("type", 0))
	var color := clampi(int(quest.get("color", 1)), 1, 5)
	var town := WorldNames.site_name(player.world, quest_target(player))
	if kind < Quests.DEFEATED:
		lines.append("Return to %s" % town)
	elif kind < 0:
		lines.append("Defeat %s" % CreatureBook.called(-kind))
	elif kind == Quests.CARD and Quests.card_for_quest(player) < 0:
		lines.append("Find a %s" % Quests.spell_name(color, int(quest["destination"])))
	elif int(quest.get("data", -1)) >= 0:
		lines.append(GO[clampi(int(quest["data"]), 0, 3)] % town)
	elif kind == Quests.CARD:
		lines.append("Take card to %s" % town)
	else:
		lines.append("Take letter to %s" % town)
	match kind:
		Quests.LETTER_LINK:
			lines.append("Reward: Mana Link")
		Quests.LETTER_AMULET:
			lines.append("Reward: %s" % Quests.amulet_name(color).capitalize())
		Quests.CARD:
			lines.append("Reward: Mana Link and an amulet")
		_:
			if kind < 0:
				lines.append(Quests.reward_line(player))
	var days := days_left(player)
	lines.append("%d %s left" % [days, "day" if days == 1 else "days"])
	return lines


## THE QUEST'S TIME RUNS OUT ([method Quests.check_deadline]): the words
## for the screen, or "" while it still runs.
static func check_quest(player: AdventurePlayer) -> String:
	return Quests.check_deadline(player)


## The creature besieging a city ([method WorldMagic.siege_creature]), or `{}`.
static func siege(player: AdventurePlayer) -> Dictionary:
	return WorldMagic.siege_creature(player)


## The city under siege, or -1.
static func siege_town(player: AdventurePlayer) -> int:
	var creature := siege(player)
	return int(creature.get("town", -1)) if not creature.is_empty() else -1


## `%1 attacking %2!` (`@QUESTSTATUS` 0: the creature's name without its
## article, the town it besieges — 1997 named the site nearest it), or "".
static func siege_line(player: AdventurePlayer) -> String:
	var creature := siege(player)
	if creature.is_empty():
		return ""
	var row := int(creature.get("creature", 0))
	var called := CreatureBook.name_of(row) if row > 0 else ""
	return "%s attacking %s!" % [called if called != "" else "A creature",
		WorldNames.site_name(player.world, int(creature.get("town", -1)))]


## The cities each wizard has tapped, black to white: their status's high
## byte holds the wizard's colour.
static func taps(player: AdventurePlayer) -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	if player.world == null:
		return counts
	for slot in player.world.sites.size():
		var ruler := TownStatus.ruler(player.world, slot)
		if ruler != 0:
			counts[ruler - 1] += 1
	return counts


## How many taps cast the Spell of Dominion for this hero.
static func dominion(player: AdventurePlayer) -> int:
	return DOMINION_WITH_RING if player.owns("Ring of the Guardian") else DOMINION


## The wizards who have tapped a city: "Red Wizardess 1 of 3", …
static func tap_lines(player: AdventurePlayer) -> Array[String]:
	var lines: Array[String] = []
	var counts := taps(player)
	for i in 5:
		if counts[i] > 0:
			lines.append("%s: %d of %d mana taps" % [WorldNames.WIZARDS[i], counts[i], dominion(player)])
	return lines


## THE NEXT DUEL'S LINE, "Next Duel: -2 lives, +3 lives, First Move", or ""
## — 1997's (`DrawAdventureQuestStatusPanel`, adventureWorldUi.c 1495–1548,
## `@QUESTSTATUS` 1–4): the lives CARRIED from the last duel first
## (`g_next_duel_life_delta`, signed), then the GIFT (`g_next_duel_card_id`):
## its extra lives, the first move, or a card in play. The two figures
## stand apart, never summed ([member AdventurePlayer.next_duel_life_carried]
## and [member AdventurePlayer.next_duel_life]); [ours: commas between the
## parts, where 1997 ran them on with spaces].
static func next_duel_line(player: AdventurePlayer) -> String:
	var parts: Array[String] = []
	for lives in [player.next_duel_life_carried, player.next_duel_life]:
		if lives > 0:
			parts.append("+%d lives" % lives)
		elif lives < 0:
			parts.append("-%d lives" % -lives)
	if player.next_duel_first_move:
		parts.append("First Move")
	if player.next_duel_card != "":
		parts.append(player.next_duel_card)
	return "Next Duel: " + ", ".join(parts) if not parts.is_empty() else ""


## Everything the quest pane shows, a line each; empty when nothing calls.
static func lines(player: AdventurePlayer) -> Array[String]:
	var out: Array[String] = []
	if player == null:
		return out
	var under_siege := siege_line(player)
	if under_siege != "":
		out.append(under_siege)
	out.append_array(quest_lines(player))
	var bonus := next_duel_line(player)
	if bonus != "":
		out.append(bonus)
	out.append_array(tap_lines(player))
	return out


## The places to guide the hero to: `{tile, kind, name}` — the city under
## siege, the quest's target.
static func targets(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or player.world == null:
		return out
	var besieged := siege_town(player)
	if besieged >= 0 and besieged < player.world.sites.size():
		var site: Dictionary = player.world.sites[besieged]
		out.append({"tile": Vector2i(int(site["x"]), int(site["y"])), "kind": "siege",
			"name": WorldNames.site_name(player.world, besieged)})
	var target := quest_target(player)
	if target >= 0 and target < player.world.sites.size():
		var site: Dictionary = player.world.sites[target]
		out.append({"tile": Vector2i(int(site["x"]), int(site["y"])), "kind": "quest",
			"name": WorldNames.site_name(player.world, target)})
	return out


# ------------------------------------------------------- the wizards' record --

## THE WIZARDS' RECORD, black to white: `{color, name, feminine, beaten,
## taps, wins, life, staff, skulls, gems}` per wizard — his colour word and
## name, his towns tapped, the hero's wins against his colour, his life in
## his stronghold, his staff's lit lights (of [constant STAFF]), the skull
## picture's step (0 none) and the gem pieces lit (see the class doc).
static func wizard_rows(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts := taps(player)
	var d := clampi(player.difficulty, 0, 3)
	for i in 5:
		var color: String = AdventurePlayer.COLORS[i]
		var beaten := color in player.defeated_wizards
		var wins := player.wins_over_color(i + 1)
		out.append({"color": color, "name": WorldNames.WIZARDS[i],
			"feminine": CreatureMeeting.wizard_feminine(i + 1), "beaten": beaten, "taps": counts[i],
			"wins": wins, "life": WiseMan.castle_life(player, i + 1),
			"staff": 0 if beaten else staff(wins, counts[i], d), "skulls": skull_step(wins),
			"gems": 0 if beaten else mini(counts[i], 5)})
	return out


## A standing wizard's staff, its lit lights of [constant STAFF]: `30 −
## min(wins, 10 + d·towns)` (aS:1736–1738, see the class doc).
static func staff(wins: int, towns: int, difficulty: int) -> int:
	var d := clampi(difficulty, 0, 3)
	var required := STAFF + 5 * d + d * towns
	var life := maxi(5 * d + 20, required - wins)
	return STAFF - (required - life)


## The skull picture for [param wins] (`duel_wins_to_skull_index`, Statwin
## main.cpp 2720): 0 for none, else the step of [constant SKULL_STEPS] —
## 1–4, 5 for 5–7, 8 for 8–11, 12 for twelve or more.
static func skull_step(wins: int) -> int:
	var step := 0
	for least in SKULL_STEPS:
		if wins >= least:
			step = least
	return step

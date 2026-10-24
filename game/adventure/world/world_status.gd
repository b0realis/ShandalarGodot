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

## Steps of the quest clock in a day.
const DAY := 16
const DOMINION := 3
const DOMINION_WITH_RING := 5
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


## "Next Duel: +2 lives, First Move, Lord of Atlantis", or "".
static func next_duel_line(player: AdventurePlayer) -> String:
	var parts: Array[String] = []
	if player.next_duel_lives() > 0:
		parts.append("+%d lives" % player.next_duel_lives())
	elif player.next_duel_lives() < 0:
		parts.append("-%d lives" % -player.next_duel_lives())
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

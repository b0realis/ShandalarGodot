extends RefCounted
## PROTOTYPE GAME DESIGN TEST: this adapter is the boundary between reusable
## Shandalar systems and one experimental island story. Keep story-specific
## decisions here so they never alter the default mainland campaign.
## Last Refuge provider. Loaded on demand through AdventureExpansions.

static func initialize(player: AdventurePlayer) -> void: RefugeCampaign.initialize(player)
static func describe(player: AdventurePlayer, tile: Vector2i) -> Dictionary: return RefugeJourney.describe(player, tile)
static func decorate_town(player: AdventurePlayer, slot: int, place: Dictionary) -> Dictionary: return RefugeJourney.decorate_town(player, slot, place)
static func ordinary_quests(_player: AdventurePlayer, slot: int) -> bool: return slot > 5
static func act(screen: WorldScreen, action: String, place: Dictionary) -> bool: return RefugeJourney.act(screen, action, place)
static func status_lines(player: AdventurePlayer) -> Array[String]: return RefugeCampaign.status_lines(player)
static func targets(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in 5:
		if RefugeCampaign.completed(player, index): continue
		var target := RefugeQuests.destination(player, index)
		target["kind"] = "quest"
		out.append(target)
	if out.is_empty(): out.append(RefugeCampaign.next_target(player))
	return out
static func deck_line(player: AdventurePlayer, cards: Array) -> String:
	var gate := RefugeCampaign.gate_for_cards(cards)
	return "Last Refuge: FE nonlands %d/%d · need %d · %d/5 pledges" % [gate["count"], gate["total"], maxi(1, ceili(float(gate["total"]) / 2)), player.refuge.get("quests", []).size()]
static func roaming_tier(_player: AdventurePlayer, tier: int) -> int: return RefugeEncounters.roaming_tier(tier)
static func tales(_player: AdventurePlayer) -> Array: return RefugeStories.TALES
static func news(player: AdventurePlayer) -> String: return RefugeStories.news(player)
static func applause(player: AdventurePlayer) -> String: return RefugeStories.applause(player)
static func roaming_words(player: AdventurePlayer, wins: int) -> Array[String]: return RefugeStories.roaming_words(player, wins)
static func dungeon_words(_player: AdventurePlayer) -> String: return RefugeStories.VAULT
static func entered(player: AdventurePlayer) -> void:
	RefugeQuests.ensure_objectives(player)
	RefugeQuests.refresh_appearance(player)

static func task_rows(data: Dictionary, progress: Dictionary) -> Array[Dictionary]:
	return RefugeQuests.task_rows(data, progress)

static func generate(seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	return RefugeWorld.generate(seed_value, color, difficulty)

static func roaming_encounter(player: AdventurePlayer, meeting: Dictionary) -> void:
	RefugeEncounters.roaming(player, meeting)

static func study_decks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in 6:
		out.append({"name": RefugeEncounters.ROAMING_NAMES[index] if index < 5 else "Ebon Crown", "life": RefugeEncounters.LIVES[index], "deck": RefugeEncounters.deck(index)})
	return out

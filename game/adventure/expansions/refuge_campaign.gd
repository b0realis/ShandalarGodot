class_name RefugeCampaign
extends RefCounted
## PROTOTYPE GAME DESIGN TEST: pledges, deck gates and card unlocks explore
## how an optional journey can teach deck building without replacing the main
## campaign. These design choices remain subject to playtesting and revision.
## The Last Refuge: new game fiction about descendants of Sarpadian
## refugees. The island is in Shandalar; the ship crosses no planar barrier.

const MAINLAND := "mainland"
const ISLAND := "refuge"
const QUESTS := [
	["white", "The Bread Road", "Leitbur's Rest remembers Icatia's soldiers and its divisive zealots. Some keepers would feed only the faithful. Carry their grain warrant to Refuge Harbor for everyone, then return to defeat the Crown's tithe-collector.", "Ebon Crown Tithe-Collector"],
	["blue", "A Harbor for Both Peoples", "Vodalian fishers and homarids have made a new harbor pact, despite their ancestors' wars. The Crown's captain commands sea magic to blockade them. Neither people trusts the other's charts. Survey the disputed channel first, then return to defeat the captain and reopen it to both.", "The Blockade Captain"],
	["black", "No More Masters", "Free thrulls live here beside people who rejected the Ebon Hand. The Crown's overseer would drag them back into breeding pits. Defeat him and defend their freedom.", "The Pit Overseer"],
	["red", "The Mountain Road", "Dwarven smiths and goblin traders refuse to repeat their ancestors' wars. They share a mountain pass, but the Crown's raiders demand tribute. Both accuse the other of paying the raider. Seek him where the road's travelers shelter and break the tribute barrier there.", "The Tribute-Raider"],
	["green", "Room to Grow", "Havenwood's elves and thallids tend an uneasy border. The Crown's sporekeeper spreads unchecked growth to drive them apart. Defeat the sporekeeper and protect the grove's balance.", "The Crown's Sporekeeper"],
]
static func on_island(player: AdventurePlayer) -> bool:
	return player != null and player.world != null and player.world.expansion.get("region", MAINLAND) == ISLAND

static func available() -> bool:
	return AdventureExpansions.enabled(ISLAND)

static func initialize(player: AdventurePlayer) -> void:
	AdventureExpansions.initialize(player)

## Disabled packs add no mainland places. Saved coordinates and progress stay
## intact, and an adventurer already on the island always keeps the way home.
static func places_visible(world: ShandalarWorld) -> bool:
	return world != null and (world.expansion.get("region", MAINLAND) == ISLAND or AdventureExpansions.enabled_in(world, ISLAND))

static func marker(world: ShandalarWorld, tile: Vector2i) -> String:
	if not places_visible(world):
		return ""
	for key in ["port", "castle"]:
		var point: Array = world.expansion.get(key, [])
		if point.size() == 2 and tile == Vector2i(int(point[0]), int(point[1])):
			return key
	return ""

static func snapshot(player: AdventurePlayer) -> Dictionary:
	return AdventureRegions.snapshot(player)

static func restore(player: AdventurePlayer, region: Dictionary) -> void:
	AdventureRegions.restore(player, region)

static func travel(player: AdventurePlayer) -> bool:
	initialize(player)
	var returning := on_island(player)
	if not returning and not AdventureExpansions.enabled_for(player, ISLAND): return false
	var seed_value := player.world.seed
	var color := player.world.color
	var make := func() -> ShandalarWorld: return AdventureExpansions.generate(ISLAND, seed_value, color, player.difficulty)
	if not AdventureRegions.travel(player, MAINLAND if returning else ISLAND, make): return false
	if not returning:
		player.log_clue(RefugeStories.GATE, "quest_clue")
		player.log_clue("Refuge Harbor always offers a free voyage home. Petitions wait; mainland deadlines pause while you are away.")
	player.log_event("voyage", "Returned to Shandalar's mainland." if returning else "Sailed to the Last Refuge.")
	return true

static func valid_saved(data: Dictionary) -> bool:
	return AdventureRegions.valid_saved(data)

static func extra_links(player: AdventurePlayer) -> int:
	return AdventureRegions.extra_links(player)

static func next_target(player: AdventurePlayer) -> Dictionary:
	if not on_island(player):
		return {}
	for index in 5:
		if not completed(player, index):
			var target := RefugeQuests.destination(player, index)
			target["kind"] = "quest"
			return target
	var key := "port" if bool(player.refuge.get("liberated", false)) else "castle"
	var point: Array = player.world.expansion.get(key, [])
	return {"tile": Vector2i(point[0], point[1]), "kind": "quest", "name": "Refuge Harbor" if key == "port" else "Castle of the Ebon Crown"} if point.size() == 2 else {}

static func status_lines(player: AdventurePlayer) -> Array[String]:
	if not on_island(player):
		return []
	var target := next_target(player)
	return ["The Last Refuge: %d / 5 pledges" % player.refuge.get("quests", []).size(),
		"The island is free. Fallen Empires spells reach the mainland." if bool(player.refuge.get("liberated", false)) else "Seek %s." % target.get("name", "the five communities"),
		"The ship at Refuge Harbor always offers a free voyage home."]

static func offers_cards(player: AdventurePlayer) -> bool:
	return AdventurePacks.offers_cards(player, FallenEmpiresPack.ID)

static func deck_gate(player: AdventurePlayer) -> Dictionary:
	return gate_for_cards(player.deck_cards())

static func gate_for_cards(cards: Array) -> Dictionary:
	var count := 0
	var total := 0
	var known := true
	var names := FallenEmpiresPack.names()
	for card in cards:
		if not CardRegistry.has_card(card):
			known = false
			continue
		if CardRegistry.get_card(card).is_land():
			continue
		total += 1
		if card in names:
			count += 1
	return {"count": count, "total": total, "ready": known and total > 0 and count * 2 >= total}

static func completed(player: AdventurePlayer, quest: int) -> bool:
	return quest in player.refuge.get("quests", [])

static func finish_quest(player: AdventurePlayer, quest: int) -> bool:
	if not on_island(player) or quest < 0 or quest >= QUESTS.size() or completed(player, quest):
		return false
	var done: Array = player.refuge.get("quests", [])
	done.append(quest)
	player.refuge["quests"] = done
	var choices: Array = player.refuge.get("reward_choices", [])
	choices.append(quest)
	player.refuge["reward_choices"] = choices
	player.gold += RefugeQuests.GOLD
	player.food += RefugeQuests.FOOD
	# Pledges change this community, never the mainland mana-link progression.
	RefugeQuests.refresh_appearance(player)
	player.log_event("quest", "The Last Refuge: %s completed." % QUESTS[quest][1], {"done": true})
	claim(player)
	return true

static func claim(player: AdventurePlayer) -> int:
	var pending: Array = player.refuge.get("pending", [])
	var taken := 0
	while not pending.is_empty() and player.bag_room() > 0 and CardRegistry.has_card(String(pending[0])):
		player.add_card(String(pending.pop_front()))
		taken += 1
	player.refuge["pending"] = pending
	return taken

static func can_challenge(player: AdventurePlayer) -> bool:
	return on_island(player) and available() and player.refuge.get("quests", []).size() == 5 \
		and not bool(player.refuge.get("liberated", false)) and bool(deck_gate(player)["ready"])

static func deck_problem(player: AdventurePlayer) -> String:
	if not AdventureExpansions.launch_enabled: return AdventureExpansions.LAUNCH_HELP
	if not available(): return "Enable Pack 2: Fallen Empires in Options to begin this battle."
	if player.deck_cards().is_empty(): return "Choose a deck in a town's deck builder before beginning this battle."
	for card in player.deck_cards():
		if not CardRegistry.has_card(card): return "Your deck contains unavailable cards. Enable their packs or edit the deck in town."
	return ""

static func liberate(player: AdventurePlayer) -> bool:
	if not can_challenge(player):
		return false
	player.refuge["liberated"] = true
	RefugeQuests.refresh_appearance(player)
	# Existing shop stock can now draw from the expanded pool on restock.
	player.log_event("freed", "The Last Refuge is free. Fallen Empires spells now reach the mainland.")
	return true

static func duel_config(player: AdventurePlayer, quest: int) -> DuelConfig:
	var config := DuelConfig.new()
	var index := quest if quest >= 0 else 2
	var deck := RefugeEncounters.deck(quest)
	config.decks = [CreatureMeeting.padded_deck(player, player.deck_cards()), deck]
	config.player_names = [player.name if player.name != "" else "Adventurer", String(QUESTS[index][3]) if quest >= 0 else "Lord of the Ebon Crown"]
	var deck_name := player.deck_names[player.current_deck] if player.current_deck < player.deck_names.size() else ""
	config.deck_names = [deck_name if deck_name != "" else "Deck %d" % (player.current_deck + 1), String(QUESTS[index][1]) if quest >= 0 else "The Ebon Crown"]
	config.portraits = [player.portrait, CreatureBook.face_id(RefugeEncounters.FACES[quest if quest >= 0 else 5])]
	config.lives = [CreatureMeeting.hero_life(player), RefugeEncounters.LIVES[quest if quest >= 0 else 5]]
	config.pilots = [null, CreatureMeeting.ai_for(player.difficulty)]
	config.mulligan_rule = MtgGame.MULLIGAN_1997
	config.ai_random_play_or_draw = true
	config.pace = Settings.ai_pace()
	config.rng_seed = randi() | 1
	if player.next_duel_first_move:
		config.first_player = 0
	if player.next_duel_card != "":
		config.start_in_play = [[player.next_duel_card], []]
	config.apply_deck_colors()
	CreatureMeeting.hero_playmat(config, player)
	return config

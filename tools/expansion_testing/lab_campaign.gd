extends RefCounted
## THE EXPANSION LAB'S CAMPAIGN (adventure plugins, 2026-11-10; the lead's
## ruling on review RV2): a plugin's land played to its end as a player
## plays it, headless and cheap — on the model's own results, no duel
## fought: a duel won is what [PluginJourney]'s result makes of one,
## [method DataRegion.finish_quest] for a quest and [method
## DataRegion.win_finale] for the finale. Each quest stage by stage at its
## own places (the petition accepted at its giver, every `go` delivered at
## its target, the duel won where it stands), every reward owed chosen and
## its cards claimed, the finale won at its marker with a deck its gate
## accepts (the finale foe's own, when the hero's is not one); then the
## adventure saved and read back, on the island and again at home, and the
## land must be neither held nor damaged ([method ExpansionContract.progress_state]
## FINE). A land whose own progress its saves could not carry — two
## rewards owed for one quest, more waiting cards than its schema holds, a
## stage past a quest's steps — fails here, not in a player's campaign.
## `--games` adds real duels beside it (the Lab's baselines), never in it.

## The most `go` steps one quest may hold (the schema's step limit).
const MOST_STEPS := 8


## Play [param region] (a plugin land) to its end for [param seed_value]:
## `{region, seed, quests, rewards, finale, save_bytes, failures}`, the
## quests and rewards won, whether the finale was, the largest save, and
## what went wrong (none for a land that plays to its end).
static func play(region: String, seed_value: int) -> Dictionary:
	var failures: Array[String] = []
	var out := {"region": region, "seed": seed_value, "quests": 0, "rewards": 0, "finale": false, "save_bytes": 0,
		"failures": failures}
	var setup := AdventureSetup.new()
	setup.adventures = [region] as Array[String]
	var versions := {}
	for pack in AdventureExpansions.pack_ids(region):
		setup.packs.append(pack)
		versions[pack] = "1"
	setup.seed_text = str(seed_value)
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	var make := func() -> ShandalarWorld: return AdventureExpansions.generate(region, seed_value, player.world.color, player.difficulty)
	if not AdventureRegions.travel(player, region, make):
		failures.append("Campaign %s seed %d: the ship did not sail there." % [region, seed_value])
		return out
	var content: Object = AdventureExpansions.provider(region)
	if not content is DataRegion:
		failures.append("Campaign %s seed %d: not a plugin's land." % [region, seed_value])
		return out
	var land: DataRegion = content
	var at := "Campaign %s seed %d" % [region, seed_value]
	for index in land.quest_count():
		if _quest(player, land, index, at, failures):
			out["quests"] = int(out["quests"]) + 1
		out["rewards"] = int(out["rewards"]) + _rewards(player, land, at, failures)
	var finale: Dictionary = land.data()["quests"]["finale"]
	_deck_for_gate(player, land, finale)
	var point: Variant = player.world.expansion.get(String(finale.get("at", "castle")))
	if point is Array:
		_walk(player, Vector2i(int(point[0]), int(point[1])))
	if not land.can_challenge(player):
		failures.append("%s: the finale cannot be challenged once every quest is won (its conditions do not hold)." % at)
	elif land.deck_problem(player) != "":
		failures.append("%s: the finale's duel cannot begin: %s" % [at, land.deck_problem(player)])
	elif not land.win_finale(player) or not land.flag(player, String(finale["done_flag"])):
		failures.append("%s: the finale was won but %s is not set." % [at, finale["done_flag"]])
	else:
		out["finale"] = true
	out["rewards"] = int(out["rewards"]) + _rewards(player, land, at, failures)
	_read_back(player, land, "%s, on the island" % at, out)
	if not AdventureRegions.travel(player, AdventureRegions.MAINLAND):
		failures.append("%s: the ship did not sail home." % at)
	_read_back(player, land, "%s, at home" % at, out)
	return out


## Quest [param index] won as a player wins it; false (said in
## [param failures]) when a stage would not move.
static func _quest(player: AdventurePlayer, land: DataRegion, index: int, at: String, failures: Array[String]) -> bool:
	var steps: Array = land.quests()[index]["steps"]
	var name := "%s quest %d" % [at, index]
	_walk(player, land.destination(player, index)["tile"])
	if String(steps[0]["do"]) == "accept" and not land.start(player, index):
		failures.append("%s: its petition could not be accepted." % name)
		return false
	for n in MOST_STEPS:
		if String(land.step(player, index).get("do", "")) != "go": break
		_walk(player, land.destination(player, index)["tile"])
		if not land.deliver(player, index):
			failures.append("%s: its go step %d could not be delivered at its target." % [name, land.stage(player, index)])
			return false
	_walk(player, land.destination(player, index)["tile"])
	if land.deck_problem(player) != "":
		failures.append("%s: its duel cannot begin: %s" % [name, land.deck_problem(player)])
		return false
	if not land.ready(player, index):
		failures.append("%s: its duel is not the step reached (stage %d)." % [name, land.stage(player, index)])
		return false
	if not land.finish_quest(player, index) or not land.completed(player, index):
		failures.append("%s: its duel was won but the quest is not done." % name)
		return false
	return true


## Every reward owed chosen (the first bundle that offers a full choice)
## and the cards claimed; how many were chosen.
static func _rewards(player: AdventurePlayer, land: DataRegion, at: String, failures: Array[String]) -> int:
	var chosen := 0
	var bundles: Array = land.data().get("rewards", {}).get("bundles", [])
	for guard in 64:
		if (land.progress(player).get("reward_choices", []) as Array).is_empty(): break
		var any := false
		for bundle in bundles.size():
			if land.choose_reward(player, bundle):
				any = true
				chosen += 1
				break
		if not any:
			failures.append("%s: a reward is owed and no bundle can be chosen." % at)
			break
	land.claim(player)
	return chosen


## The hero's deck one the finale's gate accepts: when its `deck_share`
## does not, the finale foe's own (the plugin's cards), as a player builds
## one from its rewards.
static func _deck_for_gate(player: AdventurePlayer, land: DataRegion, finale: Dictionary) -> void:
	var share := {}
	for condition: Dictionary in finale.get("conditions", []):
		if condition.has("deck_share"): share = condition["deck_share"]
	if share.is_empty() or bool(land.gate_for_cards(player.deck_cards(true), share)["ready"]):
		return
	for card: Dictionary in player.cards:
		(card["decks"] as Array).erase(player.current_deck)
	for card in DataRegion.deck_of(land.foe_for(-1)):
		player.cards.append({"card": String(card), "decks": [player.current_deck]})


static func _walk(player: AdventurePlayer, tile: Vector2i) -> void:
	if tile.x >= 0 and tile.y >= 0:
		player.position = tile * 32 + Vector2i(16, 16)


## The adventure saved and read back as a player's resume reads it: the
## land neither held nor damaged, its quests and finale kept.
static func _read_back(player: AdventurePlayer, land: DataRegion, at: String, out: Dictionary) -> void:
	var failures: Array[String] = out["failures"]
	var text := JSON.stringify(player.to_dict())
	out["save_bytes"] = maxi(int(out["save_bytes"]), text.to_utf8_buffer().size())
	var parsed: Variant = JSON.parse_string(text)
	var again: AdventurePlayer = AdventurePlayer.from_dict(parsed) if parsed is Dictionary else null
	if again == null:
		failures.append("%s: the save could not be read back." % at)
		return
	var region := land.id
	if AdventureExpansions.held(again, region):
		failures.append("%s: the land is held when the save is read back (its ships would not sail)." % at)
	var state: Variant = again.expansions.get(region)
	var fit := ExpansionContract.progress_state(AdventureExpansions.definition(region), state)
	if fit != ExpansionContract.FINE:
		failures.append("%s: the saved progress reads back %s, not FINE." % [at, "BROKEN" if fit == ExpansionContract.BROKEN else "CHANGED"])
	if not state is Dictionary:
		return
	if (state.get("quests", []) as Array).size() != int(out["quests"]):
		failures.append("%s: %d quests read back done of %d won." % [at, (state.get("quests", []) as Array).size(), out["quests"]])
	var done_flag := String(land.data()["quests"]["finale"]["done_flag"])
	if bool(out["finale"]) and not bool(state.get(done_flag, false)):
		failures.append("%s: %s reads back unset." % [at, done_flag])

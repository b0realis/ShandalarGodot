class_name RefugeJourney
extends RefCounted
## The island's conversations and battles use the adventure's existing
## illustrated visit pane and full duel host.

static func describe(player: AdventurePlayer, tile: Vector2i) -> Dictionary:
	var kind := RefugeCampaign.marker(player.world, tile)
	if kind == "":
		return {}
	var island := RefugeCampaign.on_island(player)
	if kind == "port":
		var lines: Array = [RefugeStories.ORIGIN, RefugeStories.VOYAGE, RefugeStories.DANGER, RefugeStories.GATE]
		if island:
			lines = ["The ship is ready to take you home. Your work here will wait for your return.", RefugeStories.news(player)]
		elif bool(player.refuge.get("liberated", false)):
			lines = ["The captain welcomes the liberator of the Last Refuge. The communities are free, and their spells now reach the mainland.", "Sail back to explore, trade or collect waiting rewards. Both voyages remain free."]
		if not player.refuge.get("pending", []).is_empty():
			lines.append("%d reward cards are waiting at a community or the castle; make room in your bag to collect them." % player.refuge["pending"].size())
		var actions: Array = [["refuge_sail", "Sail to Shandalar" if island else "Sail to the Island", island or RefugeCampaign.available()],
			["refuge_leave", "Mindfully leave the coastal town", true]]
		if island:
			for index in [0, 1]:
				if RefugeQuests.stage(player, index) == 1 and RefugeQuests.destination(player, index)["tile"] == tile:
					lines.append(RefugeQuests.guidance(player, index))
					actions.push_front(["refuge_deliver_%d" % index, "Deliver the grain warrant" if index == 0 else "Survey the shared channel", RefugeCampaign.available()])
		return {"expansion": "refuge", "kind": "refuge_port", "slot": -1, "name": "Refuge Harbor" if island else "Sarpadian Anchorage",
			"subtitle": "The Last Refuge", "picture": "refuge_harbor", "lines": lines,
			"actions": actions}
	var gate := RefugeCampaign.deck_gate(player)
	var required := maxi(1, ceili(float(gate["total"]) / 2.0))
	var free := bool(player.refuge.get("liberated", false))
	if free:
		return {"kind": "refuge_castle", "slot": -1, "name": "Castle of the Ebon Crown", "subtitle": "The Last Refuge — Liberated",
			"picture": "refuge_castle", "lines": ["The Ebon Crown is broken. The communities govern themselves; the castle no longer commands their roads.",
				"Fallen Empires cards now reach mainland traders, rewards and newly stocked shops. Your mainland adventure continues."],
			"actions": reward_actions(player) + [["refuge_leave", "Leave the castle", true]]}
	return {"kind": "refuge_castle", "slot": -1, "name": "Castle of the Ebon Crown", "subtitle": "The Last Refuge",
		"picture": "refuge_castle", "lines": ["Beyond these gates rules the Lord of the Ebon Crown. Win the five communities' pledges and bring their spells to answer his challenge." if not free else "The Ebon Crown is broken. The island's people govern themselves, and their spells travel freely to the mainland.",
			"Pledges: %d of 5. Your main deck: %d of %d nonland cards are from Fallen Empires." % [player.refuge.get("quests", []).size(), gate["count"], gate["total"]],
			"Required: at least %d Fallen Empires nonlands (at least 50%%). All lands are excluded." % required,
			"The communities ask you to carry their spells into this final challenge. No ante is staked; a loss or draw lets you try again."] + ([RefugeCampaign.deck_problem(player)] if RefugeCampaign.deck_problem(player) != "" else []),
		"actions": [["refuge_boss", "Challenge the lord", RefugeCampaign.can_challenge(player) and RefugeCampaign.deck_problem(player) == ""],
			["refuge_leave", "Leave the castle", true]] + reward_actions(player)}

static func decorate_town(player: AdventurePlayer, slot: int, place: Dictionary) -> Dictionary:
	if not RefugeCampaign.on_island(player): return place
	if slot >= 1 and slot <= 5:
		var index := slot - 1
		place["lines"] = [RefugeStories.EPILOGUES[index] if RefugeCampaign.completed(player, index) else "The Last Refuge — %s. Hear the community's petition here." % RefugeCampaign.QUESTS[index][1]]
		# Replace the wise man's action by identity, keeping shared services.
		var action := ["refuge_quest", "Hear the community" if not RefugeCampaign.completed(player, index) else "The community's thanks", true]
		var replaced := false
		for i in place["actions"].size():
			if place["actions"][i][0] == "wiseman":
				place["actions"][i] = action
				replaced = true
				break
		if not replaced: place["actions"].insert(mini(3, place["actions"].size()), action)
	if slot == RefugeQuests.destination_slot(player, 1) and RefugeQuests.stage(player, 1) == 1:
		place["lines"].append("The fishers disagree about whose boats may use the channel. Record a shared route before asking either people to fight for the pact.")
		place["actions"].push_front(["refuge_deliver_1", "Survey the shared channel", RefugeCampaign.available()])
	if slot == RefugeQuests.destination_slot(player, 3) and RefugeQuests.stage(player, 3) == 1 and not RefugeCampaign.completed(player, 3):
		place["lines"].append("Goblin carriers and dwarven smiths blame each other for the tolls. The Crown's raider collects from both. Hear their case before the duel.")
		place["actions"].push_front(["refuge_petition_3", "Confront the tribute-raider", true])
	return place

static func show_place(screen: WorldScreen, place: Dictionary) -> VisitPane:
	return AdventureExpansions.show_place(screen, place)

static func reward_actions(player: AdventurePlayer) -> Array:
	return [["refuge_reward", "Choose pledge cards (%d)" % player.refuge.get("reward_choices", []).size(), RefugeCampaign.available() and not player.refuge.get("reward_choices", []).is_empty()],
		["refuge_claim", "Collect waiting cards (%d)" % player.refuge.get("pending", []).size(), RefugeCampaign.available() and not player.refuge.get("pending", []).is_empty()]]

static func reward_place(player: AdventurePlayer) -> Dictionary:
	var actions: Array = []
	var lines: Array = ["Choose six Fallen Empires cards in one color for each earned pledge. Any community can teach any color; repeat a color to strengthen one deck. Cards that do not fit your bag are kept safely."]
	for color in 5:
		var cards := RefugeQuests.reward_options(player, color)
		lines.append(RefugeQuests.COLORS[color] + ": " + ", ".join(cards))
		actions.append(["refuge_reward_%d" % color, RefugeQuests.COLORS[color], cards.size() == RefugeQuests.REWARD_COUNT and not player.refuge.get("reward_choices", []).is_empty()])
	lines.append("Copy limits and bans apply. If a color has too few eligible cards, choose another or return later; your reward stays owed.")
	actions.append(["refuge_back", "Choose later", true])
	return {"kind": "refuge_reward", "slot": -1, "name": "The Communities' Spells", "subtitle": "The Last Refuge", "picture": "visit_city", "lines": lines, "actions": actions}

static func quest_place(player: AdventurePlayer, index: int) -> Dictionary:
	var complete := RefugeCampaign.completed(player, index)
	var lines: Array = [RefugeStories.EPILOGUES[index] if complete else RefugeCampaign.QUESTS[index][2]]
	var actions: Array = []
	if not complete:
		lines.append("Reward, once: choose six Fallen Empires cards in one color, 40 gold, 8 food and a pledge.")
		lines.append(RefugeQuests.guidance(player, index))
		lines.append("No ante, deadline or deck-percentage requirement. A loss or draw lets you retry. Enemy life: %d." % RefugeEncounters.LIVES[index])
		var problem := RefugeCampaign.deck_problem(player)
		if problem != "": lines.append(problem)
		if index in [0, 1, 3] and RefugeQuests.stage(player, index) == 0:
			actions.append(["refuge_accept_%d" % index, "Accept the petition", RefugeCampaign.available()])
		else:
			var here: bool = player.tile() == RefugeQuests.destination(player, index)["tile"]
			actions.append(["refuge_fight", "Duel: %s" % RefugeCampaign.QUESTS[index][3], RefugeQuests.ready(player, index) and here and problem == ""])
	else:
		lines.append("Your pledge is secure. Unclaimed rewards remain here or at the castle.")
	actions.append_array(reward_actions(player))
	actions.append(["refuge_back", "Return", true])
	return {"kind": "refuge_quest", "slot": index + 1, "name": RefugeCampaign.QUESTS[index][1],
		"subtitle": RefugeWorld.TOWNS[index], "picture": "visit_city", "lines": lines, "actions": actions}

static func action_index(action: String, prefix: String) -> int:
	var tail := action.trim_prefix(prefix)
	return tail.to_int() if tail.is_valid_int() and tail.to_int() >= 0 and tail.to_int() < 5 else -1

static func act(screen: WorldScreen, action: String, place: Dictionary) -> bool:
	if not action.begins_with("refuge_"):
		return false
	var player := screen.player
	if action.begins_with("refuge_accept_"):
		var index := action_index(action, "refuge_accept_")
		if index < 0: return true
		if RefugeCampaign.available() and RefugeQuests.start(player, index): screen.autosave()
		show_place(screen, quest_place(player, index))
		return true
	if action.begins_with("refuge_deliver_"):
		var index := action_index(action, "refuge_deliver_")
		if index < 0: return true
		if RefugeCampaign.available() and RefugeQuests.deliver(player, index): screen.autosave()
		screen.visit(player.tile(), false)
		return true
	if action.begins_with("refuge_petition_"):
		var index := action_index(action, "refuge_petition_")
		if index >= 0: show_place(screen, quest_place(player, index))
		return true
	if action.begins_with("refuge_reward_"):
		var index := action_index(action, "refuge_reward_")
		if index < 0: return true
		if RefugeQuests.choose_reward(player, index): screen.autosave()
		show_place(screen, reward_place(player))
		return true
	match action:
		"refuge_reward":
			show_place(screen, reward_place(player))
		"refuge_sail":
			if RefugeCampaign.travel(player):
				screen._visit_tile = Vector2i(-1, -1)
				screen.show_player(player)
				screen.autosave()
				var arrival := describe(player, player.tile())
				if not arrival.is_empty():
					show_place(screen, arrival)
				else:
					# Pack disabled on the island: the ship still returns home,
					# but there is no mainland town to reopen on arrival.
					screen._after_leaving()
		"refuge_quest":
			show_place(screen, quest_place(player, int(place["slot"]) - 1))
		"refuge_back":
			screen.visit(player.tile(), false)
		"refuge_claim":
			var count := RefugeCampaign.claim(player)
			screen.autosave()
			place = place.duplicate(true)
			place["lines"] = ["Collected %d cards. %d remain safely held for you." % [count, player.refuge.get("pending", []).size()]]
			place["actions"] = [["refuge_back", "Return", true]]
			show_place(screen, place)
		"refuge_boss", "refuge_fight":
			var index := -1 if action == "refuge_boss" else int(place["slot"]) - 1
			if RefugeCampaign.deck_problem(player) != "" or (index < 0 and not RefugeCampaign.can_challenge(player)) \
					or (index >= 0 and (index > 4 or not RefugeQuests.ready(player, index) or player.tile() != RefugeQuests.destination(player, index)["tile"])):
				return true
			var config := RefugeCampaign.duel_config(player, index)
			screen.autosave()
			var host := WorldDuels.host(screen, config, config.player_names[1],
				"Return to the main menu? This unfinished battle is not saved. Your adventure resumes before the challenge.")
			host.ended.connect(func(report: DuelReport) -> void: _result(screen, index, report), CONNECT_ONE_SHOT)
		"refuge_leave":
			screen._visit_tile = Vector2i(-1, -1)
			screen._after_leaving()
	screen._sync_rest()
	return true

static func _result(screen: WorldScreen, index: int, report: DuelReport) -> void:
	var player := screen.player
	player.clear_duel_gifts()
	var won := report != null and report.finished and report.result == DuelReport.WIN
	var words := "The battle is over. You may prepare and try again; no cards were staked."
	if won:
		if index >= 0:
			var awarded := RefugeCampaign.finish_quest(player, index)
			words = RefugeStories.EPILOGUES[index] + (" You receive 40 gold and 8 food. Choose six cards in a color of your choice; you may collect them later." if awarded else " Its reward has already been collected or held for you.")
		else:
			var freed := RefugeCampaign.liberate(player)
			words = "The Ebon Crown falls. The island is free! The five communities raise their banners, and the castle flies their gold pennant. Fallen Empires cards now join mainland traders, rewards and newly stocked shops. Your main quest continues." if freed else "The island is already free. Its communities welcome you."
			if not bool(player.refuge.get("liberated", false)):
				words = "The battle is won, but the island's challenge still requires all five pledges and a qualifying deck."
	if report != null and report.finished and report.result != DuelReport.DRAW:
		var foe: String = RefugeCampaign.QUESTS[index][3] if index >= 0 else "Lord of the Ebon Crown"
		player.log_event("duel", ("Defeated %s on the Last Refuge." if won else "Lost to %s on the Last Refuge.") % foe, {"won": won})
	WorldCreatures.clear_crowd(player, -1)
	screen.autosave()
	screen._show_hero()
	WorldDuels.world_music(screen)
	show_place(screen, {"kind": "refuge_result", "slot": index + 1, "name": "The Last Refuge", "subtitle": "Victory" if won else "The battle ends",
		"picture": "refuge_castle" if index < 0 else "visit_city", "lines": [words], "actions": reward_actions(player) + [["refuge_back", "Continue", true]]})

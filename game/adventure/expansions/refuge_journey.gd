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
		var lines: Array = [RefugeStories.ORIGIN, RefugeStories.VOYAGE]
		if island:
			lines = ["The ship is ready to take you home. Your work here will wait for your return.", RefugeStories.news(player)]
		elif bool(player.refuge.get("liberated", false)):
			lines = ["The captain welcomes the liberator of the Last Refuge. The communities are free, and their spells now reach the mainland.", "Sail back to explore, trade or collect waiting rewards. Both voyages remain free."]
		if not player.refuge.get("pending", []).is_empty():
			lines.append("%d reward cards are waiting at a community or the castle; make room in your bag to collect them." % player.refuge["pending"].size())
		if not RefugeCampaign.available() and not island:
			lines.append("Enable Pack 2: Fallen Empires in Options before sailing.")
		return {"kind": "refuge_port", "slot": -1, "name": "Refuge Harbor" if island else "Sarpadian Anchorage",
			"subtitle": "The Last Refuge", "picture": "refuge_harbor", "lines": lines,
			"actions": [["refuge_sail", "Sail to Shandalar" if island else "Sail to the Island", island or RefugeCampaign.available()],
				["refuge_leave", "Mindfully leave the coastal town", true]]}
	var gate := RefugeCampaign.deck_gate(player)
	var required := maxi(1, ceili(float(gate["total"]) / 2.0))
	var free := bool(player.refuge.get("liberated", false))
	if free:
		return {"kind": "refuge_castle", "slot": -1, "name": "Castle of the Ebon Crown", "subtitle": "The Last Refuge — Liberated",
			"picture": "refuge_castle", "lines": ["The Ebon Crown is broken. The communities govern themselves; the castle no longer commands their roads.",
				"Fallen Empires cards now reach mainland traders, rewards and newly stocked shops. Your mainland adventure continues."],
			"actions": [["refuge_claim", "Collect waiting rewards (%d)" % player.refuge.get("pending", []).size(), not player.refuge.get("pending", []).is_empty()], ["refuge_leave", "Leave the castle", true]]}
	return {"kind": "refuge_castle", "slot": -1, "name": "Castle of the Ebon Crown", "subtitle": "The Last Refuge",
		"picture": "refuge_castle", "lines": ["Beyond these gates rules the Lord of the Ebon Crown. Win the five communities' pledges and bring their spells to answer his challenge." if not free else "The Ebon Crown is broken. The island's people govern themselves, and their spells travel freely to the mainland.",
			"Pledges: %d of 5. Your main deck: %d of %d nonland cards are from Fallen Empires." % [player.refuge.get("quests", []).size(), gate["count"], gate["total"]],
			"Required: at least %d Fallen Empires nonlands (at least 50%%). All lands are excluded." % required,
			"The communities ask you to carry their spells into this final challenge. No ante is staked; a loss or draw lets you try again."] + ([RefugeCampaign.deck_problem(player)] if RefugeCampaign.deck_problem(player) != "" else []),
		"actions": [["refuge_boss", "Challenge the lord", RefugeCampaign.can_challenge(player) and RefugeCampaign.deck_problem(player) == ""],
			["refuge_claim", "Collect waiting rewards (%d)" % player.refuge.get("pending", []).size(), not player.refuge.get("pending", []).is_empty()],
			["refuge_leave", "Leave the castle", true]]}

static func decorate_town(player: AdventurePlayer, slot: int, place: Dictionary) -> Dictionary:
	if not RefugeCampaign.on_island(player) or slot < 1 or slot > 5:
		return place
	var index := slot - 1
	place["lines"] = [RefugeStories.EPILOGUES[index] if RefugeCampaign.completed(player, index) else "The Last Refuge — %s. Hear the community's petition here." % RefugeCampaign.QUESTS[index][1]]
	# Keep the shop, deck builder, food and leave actions. The regional
	# petition takes the mainland wise man's place, never its quest record.
	var action := ["refuge_quest", "Hear the community" if not RefugeCampaign.completed(player, index) else "The community's thanks", true]
	if place["actions"][2][0] == "wiseman":
		place["actions"][2] = action
	else:
		place["actions"].insert(3, action)
	return place

static func show_place(screen: WorldScreen, place: Dictionary) -> VisitPane:
	var pane := VisitPane.new()
	pane.player = screen.player
	pane.place = place
	pane.k = WorldHud.BIG if screen.hud.big else 1.0
	screen._visit = pane
	screen.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pane.grow_vertical = Control.GROW_DIRECTION_BOTH
	pane.left.connect(screen._left_place, WorldScreen.CLOSING)
	screen._hold()
	return pane

static func quest_place(player: AdventurePlayer, index: int) -> Dictionary:
	var complete := RefugeCampaign.completed(player, index)
	var lines: Array = [RefugeStories.EPILOGUES[index] if complete else RefugeCampaign.QUESTS[index][2],
		"Reward, once: 12 Fallen Empires cards, 100 gold, 20 food and a pledge." if not complete else "This pledge is already yours. Cards that did not fit your bag wait here or at the castle."]
	if not complete:
		lines.append("Win the duel here. No ante, time limit or deck-percentage requirement; a loss or draw lets you retry.")
		var problem := RefugeCampaign.deck_problem(player)
		if problem != "": lines.append(problem)
	return {"kind": "refuge_quest", "slot": index + 1, "name": RefugeCampaign.QUESTS[index][1],
		"subtitle": RefugeWorld.TOWNS[index], "picture": "visit_city",
		"lines": lines,
		"actions": [["refuge_fight", "Duel: %s" % RefugeCampaign.QUESTS[index][3], not complete and RefugeCampaign.deck_problem(player) == ""],
			["refuge_claim", "Collect waiting rewards (%d)" % player.refuge.get("pending", []).size(), not player.refuge.get("pending", []).is_empty()],
			["refuge_back", "Return to town", true]]}

static func act(screen: WorldScreen, action: String, place: Dictionary) -> bool:
	if not action.begins_with("refuge_"):
		return false
	var player := screen.player
	match action:
		"refuge_sail":
			if RefugeCampaign.travel(player):
				screen._visit_tile = Vector2i(-1, -1)
				screen.show_player(player)
				screen.autosave()
				show_place(screen, describe(player, player.tile()))
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
					or (index >= 0 and (index > 4 or RefugeCampaign.completed(player, index))):
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
			words = RefugeStories.EPILOGUES[index] + (" You receive 100 gold, 20 food and 12 cards; any that do not fit are held for you." if awarded else " Its reward has already been collected or held for you.")
		else:
			var freed := RefugeCampaign.liberate(player)
			words = "The Ebon Crown falls. The island is free! Fallen Empires cards now join mainland traders, rewards and newly stocked shops. Your main quest continues." if freed else "The island is already free. Its communities welcome you."
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
		"picture": "refuge_castle" if index < 0 else "visit_city", "lines": [words], "actions": [["refuge_back", "Continue", true]]})

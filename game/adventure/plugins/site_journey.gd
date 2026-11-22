class_name SiteJourney
extends RefCounted
## ADVENTURE PLUGINS, API 2 — the UI side of [DataSites]: what a sites
## plugin's buttons do on the world screen. A place's panes are the
## screen's own visit pane ([method WorldScreen.open_place]); a copy's card
## is picked in the screen's card list ([method WorldScreen.open_card_list]).
## Reached from [DataSites] by `load()` only, so the model side never
## compiles the world UI (the h5-1 rule, tools/test_script_entry_points.py).
##
## The buttons: `<id>_act:<site>:<action>` (a service: its effects, a
## copy, a talk, a duel or a trade), `<id>_back:<site>` (the place's pane
## again), `<id>_leave`.
##
## A PLACE'S DUEL (API 3) is the adventure's own duel host's ([WorldDuels]),
## as an island's: the stake is paid and the press counted, THEN the world
## is saved, then the duel is dealt — so a duel left for the main menu, or
## a window closed over it (nothing is saved under a duel, the owner's
## ruling 4), resumes with the stake paid and no result: never a free
## second try, never a prize had twice.


## [param screen] arrives untyped as [AdventureExpansions.act] passes it
## (the world screen, or a test's stand-in with its methods).
static func act(sites: DataSites, screen: Node, action: String, place: Dictionary) -> bool:
	if not action.begins_with(sites.id + "_"):
		return false
	var player: AdventurePlayer = screen.player
	var verb := action.trim_prefix(sites.id + "_")
	if verb.begins_with(AdventureSites.ACT.trim_prefix("_")):
		var parts := verb.trim_prefix(AdventureSites.ACT.trim_prefix("_")).split(":")
		if parts.size() == 2:
			_service(sites, screen, parts[0], parts[1])
	elif verb.begins_with(AdventureSites.BACK.trim_prefix("_")):
		var site_key := verb.trim_prefix(AdventureSites.BACK.trim_prefix("_"))
		var pane := sites.describe(player, site_key)
		if not pane.is_empty():
			screen.open_place(pane)
	else:
		screen._visit_tile = Vector2i(-1, -1)
		screen._after_leaving()
	screen._sync_rest()
	return true


## Place [param site_key]'s action [param action] pressed: its effects
## done (and the pane after), or the hero's cards listed for a copy over
## the place's pane — Never mind goes back to it.
static func _service(sites: DataSites, screen: Node, site_key: String, action: String) -> void:
	var player: AdventurePlayer = screen.player
	var entry := sites.action_of(site_key, action)
	match String(entry.get("do", "")):
		"effects", "talk":
			# A JOURNEY (`teleport`, the action's last effect): where it leads is
			# read before anything is paid — the action is refused when it leads
			# nowhere — and the hero is set down there once its other effects
			# are done; the pane is closed, and the world saved as on leaving.
			var journey := DataSites.teleport_of(entry)
			var landing := sites.teleport_tile(player, site_key, journey) if not journey.is_empty() else Vector2i(-1, -1)
			var after := sites.do_effects(player, site_key, action)
			if sites.applied and landing.x >= 0 and screen.has_method(&"carry_hero_to"):
				screen.call(&"carry_hero_to", landing)
				_refresh_hud(screen)
				var hud: Variant = screen.get(&"hud")
				if not (entry.get("result", []) as Array).is_empty() and hud is Object and (hud as Object).has_method(&"say"):
					(hud as Object).call(&"say", " ".join(after.get("lines", [])))
				screen._visit_tile = Vector2i(-1, -1)
				screen._after_leaving()
				return
			# A talk that only opens its pane changed nothing: nothing to save.
			if not DataSites.plain_talk(entry):
				screen.autosave()
				_refresh_hud(screen)
			screen.open_place(after)
		"duel":
			_duel(sites, screen, site_key, action, entry)
		"buy_card", "sell_card":
			var buying := String(entry["do"]) == "buy_card"
			var why := sites.refusal(player, site_key, entry)
			if why != "":
				screen.open_place(sites.result_place(player, site_key, [why]))
				return
			screen.open_place(sites.describe(player, site_key))
			var words := sites.values(player, site_key, entry)
			var word := "buy" if buying else "sell"
			# The number beside each card is its price: the list's own count.
			var list: Node = screen.open_card_list(sites.say(String(entry.get("pick_title", "site.%s_title" % word)), words),
				sites.say(String(entry.get("pick_line", "site.%s_line" % word)), words),
				sites.buyable(player, site_key, entry) if buying else sites.sellable(player, site_key, entry), true)
			list.picked.connect(func(card_name: String) -> void:
				screen._close_card_list()
				if screen._alive(screen._visit):
					screen._visit.queue_free()
					screen._visit = null
				var after := sites.buy_card(player, site_key, action, card_name) if buying \
					else sites.sell_card(player, site_key, action, card_name)
				screen.autosave()
				_refresh_hud(screen)
				screen.open_place(after))
		"copy_card":
			var why := sites.refusal(player, site_key, entry)
			if why != "":
				screen.open_place(sites.result_place(player, site_key, [why]))
				return
			screen.open_place(sites.describe(player, site_key))
			var words := sites.values(player, site_key, entry)
			var list: Node = screen.open_card_list(sites.say(String(entry.get("pick_title", "site.pick_title")), words),
				sites.say(String(entry.get("pick_line", "site.pick_line")), words), DataSites.copyable(player), true)
			list.picked.connect(func(card_name: String) -> void:
				screen._close_card_list()
				if screen._alive(screen._visit):
					screen._visit.queue_free()
					screen._visit = null
				var after := sites.copy_card(player, site_key, action, card_name)
				screen.autosave()
				_refresh_hud(screen)
				screen.open_place(after))
		_:
			screen._visit_tile = Vector2i(-1, -1)
			screen._after_leaving()


## A PLACE'S DUEL: refused in the plugin's words while it cannot begin
## ([method DataSites.refusal] — nothing paid); else the stake paid and the
## press counted ([method DataSites.duel_begin]), the world saved, and the
## duel dealt over the world against the plugin's foe, never scaled to the
## hero ([method PluginJourney.foe_config]).
static func _duel(sites: DataSites, screen: Node, site_key: String, action: String, entry: Dictionary) -> void:
	var player: AdventurePlayer = screen.player
	var foe := sites.foe(String(entry.get("foe", "")))
	var why := sites.refusal(player, site_key, entry)
	if why != "" or foe.is_empty():
		screen.open_place(sites.result_place(player, site_key, [why if why != "" else sites.say("site.done")]))
		return
	var cost := sites.duel_begin(player, site_key, action)
	if cost < 0:
		screen.open_place(sites.describe(player, site_key))
		return
	var deck_name := String(foe.get("deck_name", ""))
	var config: DuelConfig = PluginJourney.foe_config(player, foe, deck_name if deck_name != "" else String(sites.site(site_key).get("name", site_key)))
	screen.autosave()
	_refresh_hud(screen)
	var host := WorldDuels.host(screen, config, String(foe.get("name", "")), sites.say("site.duel_leave_question"))
	host.ended.connect(func(report: DuelReport) -> void: _duel_over(sites, screen, site_key, action, cost, report), CONNECT_ONE_SHOT)


## The duel over: its gifts spent as after any duel, the branch's effects
## applied and the result logged ([method DataSites.duel_end]), the world
## saved, its music back, and the result's pane shown.
static func _duel_over(sites: DataSites, screen: Node, site_key: String, action: String, cost: int, report: DuelReport) -> void:
	var player: AdventurePlayer = screen.player
	player.clear_duel_gifts()
	var won := report != null and report.finished and report.result == DuelReport.WIN
	var after := sites.duel_end(player, site_key, action, won, cost)
	WorldCreatures.clear_crowd(player, -1)
	screen.autosave()
	_refresh_hud(screen)
	WorldDuels.world_music(screen)
	var soundscape: Variant = screen.get(&"soundscape")
	if soundscape is Object and (soundscape as Object).has_method(&"rest"):
		(soundscape as Object).call(&"rest", false)
	screen.open_place(after)


## The gold shown again after a price is paid, and the map with a dungeon
## a service raised.
static func _refresh_hud(screen: Node) -> void:
	var hud: Variant = screen.get(&"hud")
	if hud is Object and (hud as Object).has_method(&"refresh"):
		(hud as Object).call(&"refresh")
	if screen.has_method(&"_show_hero"):
		screen.call(&"_show_hero")

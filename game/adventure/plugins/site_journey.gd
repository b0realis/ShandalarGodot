class_name SiteJourney
extends RefCounted
## ADVENTURE PLUGINS, API 2 — the UI side of [DataSites]: what a sites
## plugin's buttons do on the world screen. A place's panes are the
## screen's own visit pane ([method WorldScreen.open_place]); a copy's card
## is picked in the screen's card list ([method WorldScreen.open_card_list]).
## Reached from [DataSites] by `load()` only, so the model side never
## compiles the world UI (the h5-1 rule, tools/test_script_entry_points.py).
##
## The buttons: `<id>_act:<site>:<action>` (a service: its effects, or a
## copy), `<id>_back:<site>` (the place's pane again), `<id>_leave`.


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
		"effects":
			var after := sites.do_effects(player, site_key, action)
			screen.autosave()
			_refresh_hud(screen)
			screen.open_place(after)
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


## The gold shown again after a price is paid, and the map with a dungeon
## a service raised.
static func _refresh_hud(screen: Node) -> void:
	var hud: Variant = screen.get(&"hud")
	if hud is Object and (hud as Object).has_method(&"refresh"):
		(hud as Object).call(&"refresh")
	if screen.has_method(&"_show_hero"):
		screen.call(&"_show_hero")

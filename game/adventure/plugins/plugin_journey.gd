class_name PluginJourney
extends RefCounted
## ADVENTURE PLUGINS — the UI side of [DataRegion]: what a plugin pane's
## buttons do on the world screen, and its duels on the adventure's own
## duel host ([WorldDuels]). A region's panes are the screen's own visit
## pane ([method WorldScreen.open_place]). Reached from [DataRegion] by
## `load()` only, so the model side never compiles the world UI (the h5-1
## rule, tools/test_script_entry_points.py).
##
## The buttons, each `<id>_<verb>`: sail, leave, back, quest (at a giver),
## accept_N, deliver_N, petition_N, fight, boss, reward, reward_N, claim.

## Fallbacks for a hero or deck with no name of its own.
const HERO := "Adventurer"
const DECK := "Deck %d"


static func act(region: DataRegion, screen: WorldScreen, action: String, place: Dictionary) -> bool:
	if not action.begins_with(region.id + "_"):
		return false
	var player := screen.player
	var verb := action.trim_prefix(region.id + "_")
	for prefix in ["accept_", "deliver_", "petition_", "reward_"]:
		if not verb.begins_with(prefix): continue
		var index := _index(verb.trim_prefix(prefix), region.quest_count() if prefix != "reward_" else region.data().get("rewards", {}).get("bundles", []).size())
		if index < 0: return true
		match prefix:
			"accept_":
				if region.available() and region.start(player, index): screen.autosave()
				show_place(screen, region.quest_place(player, index))
			"deliver_":
				if region.available() and region.deliver(player, index): screen.autosave()
				screen.visit(player.tile(), false)
			"petition_":
				show_place(screen, region.quest_place(player, index))
			"reward_":
				if region.choose_reward(player, index): screen.autosave()
				show_place(screen, region.reward_place(player))
		return true
	match verb:
		"reward":
			show_place(screen, region.reward_place(player))
		"sail":
			if not _sail_aside(region, screen, place):
				_sail(region, screen)
		"quest":
			var index := region.quest_at(int(place.get("slot", -1)))
			if index >= 0: show_place(screen, region.quest_place(player, index))
		"back":
			screen.visit(player.tile(), false)
		"claim":
			var count := region.claim(player)
			screen.autosave()
			place = place.duplicate(true)
			place["lines"] = [region.say("rewards.collected", {"count": count, "left": region.progress(player).get("pending", []).size()})]
			place["actions"] = [[region.id + "_back", region.say("quest.back"), true]]
			show_place(screen, place)
		"boss", "fight":
			var index := -1 if verb == "boss" else int(place.get("quest", region.quest_at(int(place.get("slot", -1)))))
			if region.deck_problem(player) != "" or (index < 0 and not region.can_challenge(player)) \
					or (index >= 0 and (index >= region.quest_count() or not region.ready(player, index) or player.tile() != region.destination(player, index)["tile"])):
				return true
			var config := duel_config(region, player, index)
			screen.autosave()
			var host := WorldDuels.host(screen, config, config.player_names[1], region.say("duel.leave_question"))
			host.ended.connect(func(report: DuelReport) -> void: _result(region, screen, index, report), CONNECT_ONE_SHOT)
		"leave":
			screen._visit_tile = Vector2i(-1, -1)
			screen._after_leaving()
	screen._sync_rest()
	return true


## THE SHIP SAILS: the hero on the other land, the world shown, the
## adventure saved, the arrival's pane.
static func _sail(region: DataRegion, screen: WorldScreen) -> void:
	var player := screen.player
	if region.travel(player):
		screen._visit_tile = Vector2i(-1, -1)
		screen.show_player(player)
		screen.autosave()
		var arrival := region.describe(player, player.tile())
		if not arrival.is_empty():
			show_place(screen, arrival)
		else:
			# The card pack turned off on the island: the ship still
			# sails home, and no mainland pane opens on arrival.
			screen._after_leaving()


## The harbor's words while the island is made.
const SETTING_SAIL := "Setting sail..."
## Tests: 1 the island is made aside headless too, 0 never, -1 by the rule
## ([method sails_aside]).
static var sail_aside_forced := -1


## Whether a first voyage's island may be made on a worker: an engine with
## threads, a screen, not the web — the house rule ([method
## SkinWarmer.runs_here]); elsewhere it is made in place, as before.
static func sails_aside() -> bool:
	if sail_aside_forced >= 0:
		return sail_aside_forced == 1
	return OS.has_feature("threads") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


## THE FIRST VOYAGE TO AN ISLAND (0.70.11 campaign, smooth2 #4): its world
## is made on a worker — as the Embark makes the mainland — while the
## harbor's pane says [constant SETTING_SAIL], its buttons gone; made, it is
## kept for the voyage ([method AdventureExpansions.keep_made]) and the ship
## sails ([method _sail]). Escape on the waiting pane stays ashore: the
## island is kept, and the next Sail leaves at once. False when nothing was
## started — a voyage home, an island visited before, no worker here — and
## the caller sails in place.
static func _sail_aside(region: DataRegion, screen: WorldScreen, place: Dictionary) -> bool:
	var player := screen.player
	if not sails_aside() or region.on_island(player) or player.regions.has(region.id) \
			or not AdventureExpansions.enabled_for(player, region.id):
		return false
	var make := AdventureExpansions.generator(player, region.id)
	if not make.is_valid():
		return false
	var waiting := place.duplicate(true)
	waiting["lines"] = [SETTING_SAIL]
	waiting["actions"] = []
	var pane := show_place(screen, waiting)
	var box: Array = [null]
	var task := WorkerThreadPool.add_task(func() -> void: box[0] = make.call(), true, "island")
	# What it is made from, as it stands now: the adventure may be another
	# by the time it is made (a quick load).
	_sail_when_made(region, screen, pane, task, box,
		[player.world.seed, player.world.color, player.difficulty])
	return true


static func _sail_when_made(region: DataRegion, screen: WorldScreen, pane: VisitPane, task: int, box: Array,
		made_for: Array) -> void:
	var tree := screen.get_tree()
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	AdventureExpansions.keep_made(region.id, int(made_for[0]), int(made_for[1]), int(made_for[2]),
		box[0] as ShandalarWorld)
	if not is_instance_valid(screen) or not screen.is_inside_tree() or screen.player == null:
		return
	# The waiting pane left meanwhile (Escape): the hero stays ashore.
	if not is_instance_valid(pane) or pane.leaving or screen._visit != pane:
		return
	pane.queue_free()
	screen._visit = null
	_sail(region, screen)


static func show_place(screen: WorldScreen, place: Dictionary) -> VisitPane:
	return screen.open_place(place)


static func _index(tail: String, count: int) -> int:
	return tail.to_int() if tail.is_valid_int() and tail.to_int() >= 0 and tail.to_int() < count else -1


## Quest [param quest]'s duel (-1: the finale's): the hero's own deck and
## life, padded as a creature meeting pads it; no ante; the foe's fixed
## deck, life and face — never scaled to the hero.
static func duel_config(region: DataRegion, player: AdventurePlayer, quest: int) -> DuelConfig:
	var foe := region.foe_for(quest)
	var foe_deck := String(foe.get("deck_name", ""))
	if foe_deck == "": foe_deck = region.say(String(region.quests()[quest]["title"])) if quest >= 0 else region.title()
	return foe_config(player, foe, foe_deck)


## A duel against [param foe] (a plugin's `foe`: name, life, face, deck),
## its deck called [param foe_deck] — an island's quest and a place's duel
## ([code]site_journey.gd[/code]) alike.
static func foe_config(player: AdventurePlayer, foe: Dictionary, foe_deck: String) -> DuelConfig:
	var config := DuelConfig.new()
	DeckRescue.rescue(player)
	config.decks = [CreatureMeeting.padded_deck(player, player.deck_cards()), DataRegion.deck_of(foe)]
	config.player_names = [player.name if player.name != "" else HERO, String(foe.get("name", ""))]
	var deck_name := player.deck_names[player.current_deck] if player.current_deck < player.deck_names.size() else ""
	config.deck_names = [deck_name if deck_name != "" else DECK % (player.current_deck + 1), foe_deck]
	config.portraits = [player.portrait, CreatureBook.face_id(int(foe.get("face", 1)))]
	config.lives = [CreatureMeeting.hero_life(player), int(foe.get("life", 20))]
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
	CreatureMeeting.campaign_rules(config, player)
	return config


static func _result(region: DataRegion, screen: WorldScreen, index: int, report: DuelReport) -> void:
	var player := screen.player
	player.clear_duel_gifts()
	var won := report != null and report.finished and report.result == DuelReport.WIN
	var words := region.say("duel.over")
	var finale: Dictionary = region.data().get("quests", {}).get("finale", {})
	if won:
		if index >= 0:
			var awarded := region.finish_quest(player, index)
			words = region.say(String(region.quests()[index]["epilogue"])) + region.say("duel.won_reward" if awarded else "duel.won_again")
		else:
			var freed := region.win_finale(player)
			words = region.say(String(finale.get("won" if freed else "already", "")))
			if not region.flag(player, String(finale.get("done_flag", ""))):
				words = region.say(String(finale.get("unmet", "")))
	if report != null and report.finished and report.result != DuelReport.DRAW:
		var foe := String(region.foe_for(index).get("name", ""))
		player.log_event("duel", region.say("duel.won_log" if won else "duel.lost_log", {"foe": foe, "region": region.title()}), {"won": won})
	WorldCreatures.clear_crowd(player, -1)
	screen.autosave()
	screen._show_hero()
	WorldDuels.world_music(screen)
	# The place's tune, at rest under the duel ([method WorldDuels.place_tune_off]),
	# heard again: the hero stands in the town again.
	if screen.soundscape != null:
		screen.soundscape.rest(false)
	var marker: Dictionary = region.data().get("places", {}).get("markers", {}).get(String(finale.get("at", "castle")), {})
	var picture := String(marker.get("picture", "visit_city")) if index < 0 \
		else String(region.data().get("quests", {}).get("pictures", {}).get("result", "visit_city"))
	show_place(screen, {"expansion": region.id, "kind": "region_result", "slot": int(region.quests()[index]["giver"]) if index >= 0 else -1,
		"quest": index, "name": region.say("duel.title", {"region": region.title()}),
		"subtitle": region.say("duel.victory" if won else "duel.ended"), "picture": picture, "lines": [words],
		"actions": region.reward_actions(player) + [[region.id + "_back", region.say("duel.continue"), true]]})

class_name DataSites
extends RefCounted
## ADVENTURE PLUGINS, API 2 — THE INTERPRETER OF A SITES PLUGIN, one
## instance per plugin ([method AdventureSites.provider]). Model side: it
## reads the plugin's normalized `sites.json` ([method PluginSchema.read])
## and builds its places' panes, holds their conditions, applies their
## effects, prices their services and raises their dungeons. What a button
## does on the world screen is [code]site_journey.gd[/code]'s, reached by
## `load()` only (the h5-1 rule, as [DataRegion] reaches its journey).
##
## A PLACE'S PROGRESS ([member AdventurePlayer.sites], keyed by the plugin's
## id): `{uses: {"<site>.<action>": n}, flags: [names on], dungeons:
## {"<land>:<dungeon key>": encounter slot}}` and, once the plugin counted
## anything, `counters: {name: n}` (API 3) — the uses counted for the
## plugin as a whole (a guild's branches on two lands share one count).
## BUT A PRICED ACTION THAT RAISES A DUNGEON IS COUNTED LAND BY LAND
## (`"<site>.<action>@<land>"`, [method per_land]; the campaign of
## 2026-11-22): the dungeon it raises is that land's, so the secret sold on
## the mainland is still for sale on an island. A count kept under the old
## key by an older game is read for each land that holds the dungeon.
##
## API 3 (2026-11-22; the owner: *"make it easy to create new places that
## give additional context and users can make do various game mechanics"*)
## adds conditions, effects, costs (`needs`), talk panes, a roll on the
## plugin's own dice ([method AdventureSites.dice_for]; never the
## adventure's), duels against the plugin's own foes, card trades and Tasks
## rows — all still data: nothing a plugin writes is ever run.
##
## A SERVICE'S PRICES: the n-th use of an action costs its n-th price; once
## every price is paid the action is gone (the Conjuration Wizard Guild's
## 2000, 4000, 8000 and 12000 gold, and then no more). An action with no
## prices is free and never used up.

const JOURNEY := "res://game/adventure/plugins/site_journey.gd"
## The most an action is counted, and the most flags and dungeons a
## plugin's progress keeps (a damaged save's more are dropped).
const MOST_USES := 1000
## Dungeon rules (`rules` bits of an encounter slot, [WorldClues.lines]).
const RULE_BITS := {"no_color": 0x10, "no_artifacts": 0x40, "no_instants": 0x80,
	"life_carries": 0x01, "life_adds": 0x02}
const COLORS: Array[String] = ["black", "blue", "green", "red", "white"]
## The most amulets of one color an `amulet` effect leaves the hero with.
const MOST_AMULETS := 99
## The default button of each kind of action (`label` replaces it).
const LABELS := {"talk": "site.talk", "duel": "site.duel", "buy_card": "site.buy", "sell_card": "site.sell"}
## 1997's least distance ([method WorldGenerator.distance]) between a
## dungeon it places and every town, city and earlier slot: a raised
## dungeon keeps the same ([method _airy]).
const DUNGEON_GAP := 4

var id := ""
## The scan whose data this reads ([member AdventurePlugins.revision]).
var revision := 0
var _data := {}
var _per_land := {}
## Whether the last [method do_effects] paid and applied its action.
var applied := false
var _landmass_key := []
var _landmass := {}


func _init(plugin_id: String) -> void:
	id = plugin_id
	revision = AdventurePlugins.revision


func data() -> Dictionary:
	if _data.is_empty():
		_data = AdventurePlugins.data(id)
	return _data


static func _journey() -> Script:
	return load(JOURNEY) as Script


## The normalized `sites.json`.
func file() -> Dictionary:
	return data().get("sites", {})


func site(key: String) -> Dictionary:
	return file().get("sites", {}).get(key, {})


func dungeon(key: String) -> Dictionary:
	return file().get("dungeons", {}).get(key, {})


## The opponent [param key] of the plugin's `foes` (API 3), {} for none.
func foe(key: String) -> Dictionary:
	return file().get("foes", {}).get(key, {}) if key != "" else {}


## [param key]'s words in the plugin's text.json (else the engine's),
## filled with [param values].
func say(key: String, values := {}) -> String:
	return PluginText.say(data().get("text", {}), key, values)


## The plugin's name, a pane's subtitle by default.
func plugin_name() -> String:
	return String(data().get("manifest", {}).get("name", id))


# ---------------------------------------------------------- progress --

## [param player]'s progress with this plugin, {} for none (read only).
func progress(player: AdventurePlayer) -> Dictionary:
	return player.sites.get(id, {}) if player != null else {}


## The record to write into, made when missing.
func _state(player: AdventurePlayer) -> Dictionary:
	if not player.sites.has(id) or not player.sites[id] is Dictionary:
		player.sites[id] = {"uses": {}, "flags": [], "dungeons": {}}
	var state: Dictionary = player.sites[id]
	for part in ["uses", "dungeons"]:
		if not state.get(part) is Dictionary:
			state[part] = {}
	if not state.get("flags") is Array:
		state["flags"] = []
	return state


## EVERY EFFECT [param entry] MAY EVER APPLY: its own, each outcome's of a
## roll among them, and both branches' of a duel.
static func all_effects(entry: Dictionary) -> Array:
	var out: Array = []
	var lists: Array = [entry.get("effects", [])]
	for branch in ["win", "lose"]:
		if entry.get(branch) is Dictionary:
			lists.append(entry[branch].get("effects", []))
	for list: Array in lists:
		for effect: Dictionary in list:
			if effect.has("roll"):
				for outcome: Dictionary in effect["roll"].get("outcomes", []):
					out.append_array(outcome.get("effects", []))
			else:
				out.append(effect)
	return out


## The dungeons [param entry]'s effects may raise, by key.
static func spawned(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for effect: Dictionary in all_effects(entry):
		if effect.has("spawn_dungeon") and not String(effect["spawn_dungeon"]) in out:
			out.append(String(effect["spawn_dungeon"]))
	return out


## Whether [param site_key]'s [param action] is counted land by land: one
## with prices that may raise a dungeon (the class doc).
func per_land(site_key: String, action: String) -> bool:
	var key := site_key + "." + action
	if not _per_land.has(key):
		var entry := action_of(site_key, action)
		_per_land[key] = not (entry.get("prices", []) as Array).is_empty() and not spawned(entry).is_empty()
	return _per_land[key]


## How often [param player] had [param site]'s action [param action] done
## (on this land, for an action counted land by land).
func uses(player: AdventurePlayer, site_key: String, action: String) -> int:
	var counted: Variant = progress(player).get("uses", {})
	if not counted is Dictionary:
		return 0
	var plain := site_key + "." + action
	if not per_land(site_key, action):
		return int(counted.get(plain, 0))
	var here := int(counted.get(plain + "@" + land(player), 0))
	# A count an older game kept for the plugin as a whole: this land's when
	# the dungeon it paid for was raised here.
	if counted.has(plain):
		var raised: Variant = progress(player).get("dungeons", {})
		for key in spawned(action_of(site_key, action)):
			if raised is Dictionary and (raised as Dictionary).has(land(player) + ":" + key):
				return mini(MOST_USES, here + int(counted[plain]))
	return here


## Every use of [param site_key]'s actions together (a `one_of` line's turn
## `by: "uses"`).
func site_uses(player: AdventurePlayer, site_key: String) -> int:
	var counted: Variant = progress(player).get("uses", {})
	var total := 0
	if counted is Dictionary:
		for key: Variant in counted:
			if String(key).begins_with(site_key + ".") and not "#" in String(key):
				total += int(counted[key])
	return total


## The plugin's counter [param name] (API 3), 0 to [constant MOST_USES].
func counter(player: AdventurePlayer, name: String) -> int:
	var kept: Variant = progress(player).get("counters", {})
	if not kept is Dictionary or not AdventurePlayer._is_number((kept as Dictionary).get(name, 0)):
		return 0
	return clampi(int(kept[name]), 0, MOST_USES) if (kept as Dictionary).has(name) else 0


## The day of [param player]'s journey.
static func day(player: AdventurePlayer) -> int:
	return player.journey_steps() / WorldStatus.DAY


## How many copies of [param card] the hero holds, in a deck or not.
static func held(player: AdventurePlayer, card: String) -> int:
	var count := 0
	for row: Variant in player.cards:
		if row is Dictionary and String(row.get("card", "")) == card:
			count += 1
	return count


func flag(player: AdventurePlayer, name: String) -> bool:
	var on: Variant = progress(player).get("flags", [])
	return on is Array and name in on


## The action [param action] of [param site_key] (the first pane naming
## it), {} for none.
func action_of(site_key: String, action: String) -> Dictionary:
	for pane in site(site_key).get("panes", []):
		for entry in pane.get("actions", []):
			if String(entry["id"]) == action:
				return entry
	return {}


## What [param site_key]'s [param action] costs [param player] now: its
## next price, 0 when it has none, −1 when every price is paid.
func price(player: AdventurePlayer, site_key: String, action: Dictionary) -> int:
	var prices: Array = action.get("prices", [])
	if prices.is_empty():
		return 0
	var done := uses(player, site_key, String(action["id"]))
	return int(prices[done]) if done < prices.size() else -1


func used_up(player: AdventurePlayer, site_key: String, action: Dictionary) -> bool:
	return price(player, site_key, action) < 0


## How many more times [param action] can be done (−1: without end).
func uses_left(player: AdventurePlayer, site_key: String, action: Dictionary) -> int:
	var prices: Array = action.get("prices", [])
	if prices.is_empty():
		return -1
	return maxi(0, prices.size() - uses(player, site_key, String(action["id"])))


## The land [param player] stands on, its key in a dungeon record.
static func land(player: AdventurePlayer) -> String:
	return AdventureRegions.id(player.world)


## The encounter slot of dungeon [param key] this plugin raised on
## [param player]'s land, −1 for none.
func dungeon_index(player: AdventurePlayer, key: String) -> int:
	var raised: Variant = progress(player).get("dungeons", {})
	if not raised is Dictionary:
		return -1
	var saved: Variant = (raised as Dictionary).get(land(player) + ":" + key, -1)
	var index := int(saved) if AdventurePlayer._is_number(saved) else -1
	# Slots 0–4 are the castles' on every land: never a raised dungeon.
	if index < DungeonDoors.CASTLES or index >= mini(player.world.encounters.size(), WorldClues.MOST_SLOTS):
		return -1
	# THE SLOT MUST SAY IT IS THIS DUNGEON ([constant WorldClues.RAISED]; the
	# review of 2026-11-21): a damaged save's record pointed at a 1997
	# dungeon read "open" for good, and the place took its price for a
	# dungeon [method spawn] then never raised.
	var slot: Dictionary = player.world.encounters[index]
	var mark: Variant = slot.get(WorldClues.RAISED)
	if mark is String and String(mark) != "":
		return index if String(mark) == id + ":" + key else -1
	# A 0.70.4 save, from before the mark: its vault is found where only a
	# raised dungeon stands — past 1997's fifteen on the mainland; on another
	# land past the castles' slots and under the name this dungeon was given
	# (the land's own cave has the land's) — and marked from now on.
	var mainland := AdventureRegions.mainland(player)
	if mainland and index < WorldClues.SLOTS:
		return -1
	if not mainland and (dungeon(key).is_empty() or WorldNames.dungeon_name(index, player.world) != String(dungeon(key).get("name", key)) \
			or not _named(player.world, index)):
		return -1
	slot[WorldClues.RAISED] = id + ":" + key
	player.world.touch()
	return index


## Whether [param world] keeps a name of its own for slot [param index]
## (`expansion.dungeon_names`, as [method spawn] writes one).
static func _named(world: ShandalarWorld, index: int) -> bool:
	var names: Variant = world.expansion.get("dungeon_names", {})
	return names is Dictionary and (names as Dictionary).get(str(index)) is String


## "none", "open" (it still holds a card) or "cleared".
func dungeon_state(player: AdventurePlayer, key: String) -> String:
	var index := dungeon_index(player, key)
	if index < 0:
		return "none"
	return "open" if WorldClues.holds_cards(player.world.encounters[index]) else "cleared"


# -------------------------------------------------------- conditions --

func holds(player: AdventurePlayer, site_key: String, conditions: Array) -> bool:
	for condition in conditions:
		if not _holds(player, site_key, condition):
			return false
	return true


func _holds(player: AdventurePlayer, site_key: String, condition: Dictionary) -> bool:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"flag": return flag(player, String(value))
		"not_flag": return not flag(player, String(value))
		"gold_at_least": return player.gold >= int(value)
		"on_mainland": return AdventureRegions.mainland(player) == bool(value)
		"used":
			var done := uses(player, site_key, String(value["action"]))
			return done >= int(value.get("min", 0)) and done <= int(value.get("max", MOST_USES))
		"used_up": return used_up(player, site_key, action_of(site_key, String(value)))
		"dungeon": return dungeon_state(player, String(value["dungeon"])) == String(value["state"])
		# API 3.
		"has_card": return held(player, String(value["card"])) >= int(value.get("min", 1))
		"amulets":
			var color := String(value.get("color", "any"))
			return (player.amulet_count() if color == "any" else int(player.amulets.get(color, 0))) >= int(value.get("min", 1))
		"hero_color": return player.color == String(value)
		"owns_magic": return player.owns(String(value))
		"food_at_least": return player.food >= int(value)
		"gold_below": return player.gold < int(value)
		"day_at_least": return day(player) >= int(value)
		"wizards_defeated": return player.defeated_wizards.size() >= int(value)
		"at_peace": return player.at_peace() == bool(value)
		"difficulty": return player.difficulty >= int(value.get("min", 0)) and player.difficulty <= int(value.get("max", 3))
		"plugin_on": return AdventureSites.on(player, String(value)) or AdventureExpansions.enabled_for(player, String(value))
		"counter":
			var count := counter(player, String(value["name"]))
			return count >= int(value.get("min", 0)) and count <= int(value.get("max", MOST_USES))
		"site_used":
			var done := uses(player, String(value["site"]), String(value["action"]))
			return done >= int(value.get("min", 1)) and done <= int(value.get("max", MOST_USES))
		"gift_waiting": return player.duel_gift_waiting() == bool(value)
		"any":
			for option: Dictionary in value:
				if _holds(player, site_key, option):
					return true
			return false
		"life_bonus_below": return player.life_bonus < int(value)
		"town_linked":
			var town := nearest_town(player, site_key)
			return town >= 0 and TownStatus.linked(player.world, town)
	return false


## The first condition named [param word] in [param conditions] (inside an
## `any` too): its value, null for none.
static func _named_condition(conditions: Array, word: String) -> Variant:
	for condition: Dictionary in conditions:
		if condition.has(word):
			return condition[word]
		if condition.has("any"):
			var inside: Variant = _named_condition(condition["any"], word)
			if inside != null:
				return inside
	return null


# --------------------------------------------------------------- panes --

## The placeholders' values for [param site_key]'s [param action] ({} for
## a pane's lines, then [param pane] the pane): the hero's, `{price}` and
## `{uses_left}` of the action, `{dungeon}` the action's or the pane's own
## dungeon ([method dungeon_about]) — its name before it is raised too,
## never the bare word —, `{count}` the counter it names, `{foe}` and
## `{life}` a duel's opponent, `{card}` the card it gives or takes.
func values(player: AdventurePlayer, site_key: String, action := {}, more := {}, pane := {}) -> Dictionary:
	var out := {"hero": player.name if player != null else "", "gold": player.gold if player != null else 0,
		"region": AdventureExpansions.label(land(player), player) if player != null else ""}
	if player == null:
		out.merge(more, true)
		return out
	out["food"] = player.food
	out["amulets"] = player.amulet_count()
	out["day"] = day(player)
	out["life_bonus"] = player.life_bonus
	var about := dungeon_about(action, pane)
	if about != "":
		out["dungeon"] = dungeon_word(player, about)
	var counted := counter_about(action, pane)
	if counted != "":
		out["count"] = counter(player, counted)
	if not action.is_empty():
		out["price"] = maxi(0, price(player, site_key, action))
		var left := uses_left(player, site_key, action)
		out["uses_left"] = left if left >= 0 else ""
		var opponent := foe(String(action.get("foe", "")))
		if not opponent.is_empty():
			out["foe"] = String(opponent.get("name", ""))
			out["life"] = int(opponent.get("life", 20))
		var card := card_about(action)
		if card != "":
			out["card"] = card
		# {town}: the town a link would be made with (else the nearest), or a
		# journey's; {title}: the World Magic given.
		for effect: Dictionary in all_effects(action):
			if effect.has("mana_link") or (effect.has("teleport") and String(effect["teleport"].get("to", "")) == "nearest_town"):
				var town := nearest_town(player, site_key, effect.has("mana_link"))
				if town < 0:
					town = nearest_town(player, site_key)
				if town >= 0:
					out["town"] = WorldNames.site_name(player.world, town)
			elif effect.has("world_magic"):
				out["title"] = String(effect["world_magic"])
	out.merge(more, true)
	return out


## THE DUNGEON `{dungeon}` NAMES for [param action] (the first its effects
## may raise, else the one its `when` asks about) or for [param pane] (the
## one its `when` asks about, else the first one of its actions'); else the
## plugin's first dungeon; "" for a plugin with none.
func dungeon_about(action: Dictionary, pane := {}) -> String:
	for source: Dictionary in [action, pane]:
		if source.is_empty():
			continue
		var raised := spawned(source)
		if not raised.is_empty():
			return raised[0]
		var asked: Variant = _named_condition(source.get("when", []), "dungeon")
		if asked is Dictionary:
			return String(asked["dungeon"])
		for entry: Dictionary in source.get("actions", []):
			var theirs := spawned(entry)
			if not theirs.is_empty():
				return theirs[0]
	var all: Dictionary = file().get("dungeons", {})
	return String(all.keys()[0]) if not all.is_empty() else ""


## Dungeon [param key]'s name: the land's word for it once raised, the
## plugin's before.
func dungeon_word(player: AdventurePlayer, key: String) -> String:
	var index := dungeon_index(player, key)
	if index >= 0:
		return WorldNames.dungeon_name(index, player.world)
	return String(dungeon(key).get("name", key))


## The counter `{count}` shows for [param action] (the first its effects
## change, else the one its `when` asks about) or [param pane] (its
## `when`'s); else the plugin's first counter; "" for a plugin with none.
func counter_about(action: Dictionary, pane := {}) -> String:
	for source: Dictionary in [action, pane]:
		if source.is_empty():
			continue
		for effect: Dictionary in all_effects(source):
			if effect.has("counter"):
				return String(effect["counter"]["name"])
		var asked: Variant = _named_condition(source.get("when", []), "counter")
		if asked is Dictionary:
			return String(asked["name"])
	var all: Array = file().get("counters", [])
	return String(all[0]) if not all.is_empty() else ""


## The card `{card}` names for [param action]: the first it takes
## (`needs`), else the first it gives.
static func card_about(action: Dictionary) -> String:
	for need: Dictionary in action.get("needs", []):
		if need.has("card"):
			return String(need["card"])
	for effect: Dictionary in all_effects(action):
		if effect.has("give_card"):
			return String(effect["give_card"])
	return ""


func _lines(player: AdventurePlayer, site_key: String, entries: Array, filled: Dictionary) -> Array:
	var out: Array = []
	for entry in entries:
		if entry is String:
			out.append(say(entry, filled))
			continue
		if not holds(player, site_key, entry.get("when", [])):
			continue
		# A line that asks about a counter shows that one as {count}.
		var own := filled
		var asked: Variant = _named_condition(entry.get("when", []), "counter")
		if asked is Dictionary:
			own = filled.duplicate()
			own["count"] = counter(player, String(asked["name"]))
		if entry.has("one_of"):
			# In turn, by the day or by the place's uses: no dice.
			var options: Array = entry["one_of"]
			var turn := day(player) if String(entry.get("by", "day")) == "day" else site_uses(player, site_key)
			out.append(say(String(options[posmod(turn, options.size())]), own))
		else:
			out.append(say(String(entry["text"]), own))
	return out


## THE PANE [method describe] SHOWS: the pane named [param pane_id] (a
## talk's, API 3) while its `when` holds, else the first pane without an id
## whose `when` holds.
func pane_of(player: AdventurePlayer, site_key: String, pane_id := "") -> Dictionary:
	var panes: Array = site(site_key).get("panes", [])
	if pane_id != "":
		for option: Dictionary in panes:
			if String(option.get("id", "")) == pane_id and holds(player, site_key, option.get("when", [])):
				return option
	for option: Dictionary in panes:
		if not option.has("id") and holds(player, site_key, option.get("when", [])):
			return option
	return {}


## The words of [param action]'s button: its `label`, else its kind's own.
func label_key(action: Dictionary) -> String:
	if action.has("label"):
		return String(action["label"])
	var kind := String(action["do"])
	if LABELS.has(kind):
		return LABELS[kind]
	for need: Dictionary in action.get("needs", []):
		if need.has("card"):
			return "site.give"
	return "site.pay"


## THE PANE OF PLACE [param site_key] for [param player]: the first pane
## whose `when` holds ([method pane_of]; [param pane_id] a talk's pane) —
## its lines, and each action whose `when` holds and that is not used up,
## `[button, words, ready]` (ready: the hero carries its price and what it
## needs, and for a copy has a card to copy and room for it).
func describe(player: AdventurePlayer, site_key: String, pane_id := "") -> Dictionary:
	var place := site(site_key)
	if place.is_empty():
		return {}
	var pane := pane_of(player, site_key, pane_id)
	var filled := values(player, site_key, {}, {}, pane)
	var actions: Array = []
	for action in pane.get("actions", []):
		if not holds(player, site_key, action.get("when", [])):
			continue
		var name := String(action["id"])
		match String(action["do"]):
			"leave":
				actions.append([id + AdventureSites.LEAVE, say(String(action.get("label", "site.leave"))), true])
			_:
				if used_up(player, site_key, action):
					continue
				var words := values(player, site_key, action)
				# Ready only when the press would be taken: [method do_effects]
				# also refuses a dungeon no slot or tile can hold.
				var ready := refusal(player, site_key, action) == ""
				if ready and String(action["do"]) in ["effects", "talk"]:
					ready = _spawn_problem(player, action, site_key) == ""
				actions.append([id + AdventureSites.ACT + site_key + ":" + name,
					say(label_key(action), words), ready])
	return {"expansion": id, "kind": AdventureSites.PANE_KIND, "site": site_key, "slot": -1,
		"pane": String(pane.get("id", "")),
		"name": say(String(pane["title"]), filled) if pane.has("title") else String(place.get("name", site_key)),
		"subtitle": say(String(pane["subtitle"]), filled) if pane.has("subtitle") else plugin_name(),
		"picture": String(pane.get("picture", place.get("picture", "visit_city"))),
		"lines": _lines(player, site_key, pane.get("lines", []), filled), "actions": actions}


## WHY [param site_key]'s [param action] cannot be done now, in the
## plugin's words; "" when it can: its conditions hold, it is not used up,
## the hero carries its price and what it `needs` — and for a copy, a card
## may be copied and the bag has room; for effects, each can be had (room
## for a card given, no gift waiting for one given, no dungeon paid for
## that is open already); for a duel, a deck to fight with; for a trade, a
## card to trade. Asked before anything is paid.
func refusal(player: AdventurePlayer, site_key: String, action: Dictionary) -> String:
	if action.is_empty() or not holds(player, site_key, action.get("when", [])) or used_up(player, site_key, action):
		return say("site.done")
	var cost := price(player, site_key, action)
	if player.gold < cost:
		return say("site.no_gold", {"price": cost, "gold": player.gold})
	var lacking := _needs_problem(player, action)
	if lacking != "":
		return lacking
	match String(action["do"]):
		"copy_card":
			if player.bag_room() < 1:
				return say("site.bag_full")
			if copyable(player).is_empty():
				return say("site.no_cards")
		"effects", "talk":
			return _effects_problem(player, action, effects_now(player, site_key, action)["effects"], site_key)
		"duel":
			var deck := deck_problem(player)
			if deck != "":
				return deck
			for branch in ["win", "lose"]:
				var why := _effects_problem(player, action, action.get(branch, {}).get("effects", []), site_key)
				if why != "":
					return why
		"buy_card":
			if player.bag_room() < 1:
				return say("site.bag_full")
			if buyable(player, site_key, action).is_empty():
				return say("site.no_stock")
		"sell_card":
			if sellable(player, site_key, action).is_empty():
				return say("site.nothing_to_sell")
	return ""


## What of [param action]'s `needs` the hero lacks, "" for nothing.
func _needs_problem(player: AdventurePlayer, action: Dictionary) -> String:
	var cards := {}
	var amulets: Dictionary = player.amulets.duplicate()
	var food := player.food
	for need: Dictionary in action.get("needs", []):
		var key: String = need.keys()[0]
		var value: Variant = need[key]
		match key:
			"card":
				cards[value] = int(cards.get(value, 0)) + 1
				if held(player, String(value)) < int(cards[value]):
					return say("site.needs_card", {"card": value})
			"amulets":
				var color := String(value.get("color", "any"))
				if not _take_amulets(amulets, color, int(value.get("count", 1))):
					if color == "any":
						return say("site.needs_any_amulets", {"count": int(value.get("count", 1)), "amulets": player.amulet_count()})
					return say("site.needs_amulets", {"count": int(value.get("count", 1)), "color": color})
			"food":
				food -= int(value)
				if food < 0:
					return say("site.needs_food", {"count": int(value), "food": player.food})
	return ""


## [param count] amulets of [param color] taken out of [param amulets]
## (`{color: n}`) — of "any": one at a time from the color there is most of,
## black first among equals. False, and nothing sure about what was taken,
## when there are too few (asked on a copy first, [method _needs_problem]).
static func _take_amulets(amulets: Dictionary, color: String, count: int) -> bool:
	if color != "any":
		if int(amulets.get(color, 0)) < count:
			return false
		amulets[color] = int(amulets.get(color, 0)) - count
		return true
	for taken in count:
		var best := ""
		for hue in COLORS:
			if int(amulets.get(hue, 0)) > (int(amulets.get(best, 0)) if best != "" else 0):
				best = hue
		if best == "":
			return false
		amulets[best] = int(amulets[best]) - 1
	return true


## One copy of [param card] out of the hero's cards: one in no deck first,
## else the one in the fewest decks (it leaves them). False for none held.
static func take_card(player: AdventurePlayer, card: String) -> bool:
	var best := -1
	var fewest := 1 << 30
	for i in player.cards.size():
		var row: Variant = player.cards[i]
		if row is Dictionary and String(row.get("card", "")) == card:
			var decks := (row["decks"] as Array).size() if row.get("decks") is Array else 0
			if decks < fewest:
				best = i
				fewest = decks
	if best < 0:
		return false
	player.cards.remove_at(best)
	return true


## [param action] paid: [param cost] gold and everything it `needs`.
func _pay(player: AdventurePlayer, action: Dictionary, cost: int) -> void:
	player.gold -= cost
	for need: Dictionary in action.get("needs", []):
		var key: String = need.keys()[0]
		var value: Variant = need[key]
		match key:
			"card": take_card(player, String(value))
			"amulets": _take_amulets(player.amulets, String(value.get("color", "any")), int(value.get("count", 1)))
			"food": player.food = maxi(0, player.food - int(value))


## THE EFFECTS [param entry] APPLIES NOW, `{effects, result}`: its own in
## order, a `roll` replaced by the effects of the outcome drawn ([method
## rolled]) and that outcome's lines in `result`.
func effects_now(player: AdventurePlayer, site_key: String, entry: Dictionary) -> Dictionary:
	var out := {"effects": [], "result": []}
	for effect: Dictionary in entry.get("effects", []):
		if effect.has("roll"):
			var outcome := rolled(player, site_key, entry, effect["roll"])
			(out["effects"] as Array).append_array(outcome.get("effects", []))
			(out["result"] as Array).append_array(outcome.get("result", []))
		else:
			(out["effects"] as Array).append(effect)
	return out


## THE OUTCOME OF [param roll] for this use of [param entry]: one by its
## weight, on the plugin's own dice ([method AdventureSites.dice_for]) for
## this land, place, action and use — the adventure's dice are never cast,
## and the same save rolls the same again.
func rolled(player: AdventurePlayer, site_key: String, entry: Dictionary, roll: Dictionary) -> Dictionary:
	var outcomes: Array = roll.get("outcomes", [])
	if outcomes.is_empty():
		return {}
	var total := 0
	for outcome: Dictionary in outcomes:
		total += maxi(1, int(outcome.get("weight", 1)))
	var name := String(entry["id"])
	# The use stands first in the key: FNV-1a mixes what comes early through
	# every later byte, and the dice's first draw is only as mixed as its
	# seed (the use last gave runs of one outcome, use after use).
	var dice := AdventureSites.dice_for(player.world, int(file().get("salt", 0)),
		"%d:roll:%s:%s:%s" % [uses(player, site_key, name), id, site_key, name])
	var at := dice.below(total)
	for outcome: Dictionary in outcomes:
		at -= maxi(1, int(outcome.get("weight", 1)))
		if at < 0:
			return outcome
	return outcomes.back()


## Why [param effects] of [param action] cannot be had now, "" when they
## can — asked before anything is paid: a dungeon paid for that is open
## already (the campaign of 2026-11-22: the price was taken for nothing), a
## card and no room in the bag or no more copies allowed ([method
## CardShop.classic_allows]), a gift for the next duel while one waits.
func _effects_problem(player: AdventurePlayer, action: Dictionary, effects: Array, site_key := "") -> String:
	var given := 0
	var rule := {}
	var rule_read := false
	for effect: Dictionary in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"spawn_dungeon":
				if not (action.get("prices", []) as Array).is_empty() and dungeon_state(player, String(value)) == "open":
					return say("site.dungeon_open", {"dungeon": dungeon_word(player, String(value))})
			"give_card":
				given += 1
				if player.bag_room() < given:
					return say("site.bag_full")
				if not rule_read:
					rule = CardShop.classic_rule(player).duplicate(true)
					rule_read = true
				if not CardShop.classic_allows(rule, String(value)):
					return say("site.card_limit", {"card": value})
				if not rule.is_empty():
					rule["owned"][String(value)] = int(rule["owned"].get(String(value), 0)) + 1
			"next_duel":
				if player.duel_gift_waiting():
					return say("site.gift_waiting")
			"world_magic":
				if player.owns(String(value)):
					return say("site.magic_owned", {"title": value})
			"mana_link":
				if nearest_town(player, site_key, true) < 0:
					return say("site.no_link")
			"life_bonus":
				if player.life_bonus >= AdventurePlayer.LIFE_BONUS_MOST:
					return say("site.life_full")
			"teleport":
				if teleport_tile(player, site_key, value).x < 0:
					return say("site.no_way")
	return ""


## Why no duel may begin now, "" when one may: no deck chosen, or a card in
## it this game does not know (as [method DataRegion.deck_problem]).
func deck_problem(player: AdventurePlayer) -> String:
	var cards := player.deck_cards(true)
	if cards.is_empty():
		return say("deck.empty")
	for card in cards:
		if not CardRegistry.has_card(card):
			return say("deck.unknown")
	return ""


## The pane after an action, [param lines] (its `result`, else nothing to
## add) with a way back to the place and out.
func result_place(player: AdventurePlayer, site_key: String, lines: Array) -> Dictionary:
	var pane := describe(player, site_key)
	pane["lines"] = lines
	pane["actions"] = [[id + AdventureSites.BACK + site_key, say("site.back"), true], [id + AdventureSites.LEAVE, say("site.leave"), true]]
	return pane


# ------------------------------------------------------------ actions --

## Whether [param entry] is a talk that only opens its pane: nothing paid,
## nothing applied, nothing counted or saved.
static func plain_talk(entry: Dictionary) -> bool:
	return String(entry.get("do", "")) == "talk" and (entry.get("prices", []) as Array).is_empty() \
		and (entry.get("effects", []) as Array).is_empty() and (entry.get("needs", []) as Array).is_empty()


## A SERVICE DONE: [param site_key]'s effects action [param action] (or a
## talk with a price or effects) paid and its effects applied, its use
## counted. The pane to show next: its `result` lines and a roll's (none:
## the place's pane again; a talk: the pane it names), or why it could not
## be done — nothing paid then.
func do_effects(player: AdventurePlayer, site_key: String, action: String) -> Dictionary:
	applied = false
	var entry := action_of(site_key, action)
	if entry.is_empty() or not String(entry["do"]) in ["effects", "talk"]:
		return describe(player, site_key)
	var why := refusal(player, site_key, entry)
	if why == "":
		why = _spawn_problem(player, entry, site_key)
	if why != "":
		return result_place(player, site_key, [why])
	var talk := String(entry["do"]) == "talk"
	if plain_talk(entry):
		return describe(player, site_key, String(entry.get("to", "")))
	# Drawn before the use is counted: the roll is this use's.
	var now := effects_now(player, site_key, entry)
	var cost := price(player, site_key, entry)
	var filled := values(player, site_key, entry)
	_pay(player, entry, cost)
	_count(player, site_key, action)
	apply(player, site_key, now["effects"], filled)
	applied = true
	if talk:
		return describe(player, site_key, String(entry.get("to", "")))
	var lines: Array = (entry.get("result", []) as Array) + (now["result"] as Array)
	if lines.is_empty():
		return describe(player, site_key)
	var after := values(player, site_key, entry, {"price": cost})
	return result_place(player, site_key, _lines(player, site_key, lines, after))


## A COPY MADE: [param site_key]'s copy action [param action] paid and one
## more [param card] in the bag ([method AdventurePlayer.add_card]), its
## use counted — only a card the hero holds and may hold one more of
## ([method copyable]).
func copy_card(player: AdventurePlayer, site_key: String, action: String, card: String) -> Dictionary:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "copy_card":
		return describe(player, site_key)
	var why := refusal(player, site_key, entry)
	if why == "" and not copyable(player).has(card):
		why = say("site.no_cards")
	if why != "":
		return result_place(player, site_key, [why])
	var cost := price(player, site_key, entry)
	if not player.add_card(card):
		return result_place(player, site_key, [say("site.bag_full")])
	_pay(player, entry, cost)
	_count(player, site_key, action)
	var filled := values(player, site_key, {}, {"price": cost, "card": card})
	player.log_event("site", say("site.copied_log", filled), {"card": card, "site": id + ":" + site_key})
	var lines := _lines(player, site_key, entry.get("result", []), filled)
	return result_place(player, site_key, lines if not lines.is_empty() else [say("site.copied", filled)])


func _count(player: AdventurePlayer, site_key: String, action: String) -> void:
	_count_key(player, site_key + "." + action + ("@" + land(player) if per_land(site_key, action) else ""))


func _count_key(player: AdventurePlayer, key: String) -> void:
	var counted: Dictionary = _state(player)["uses"]
	counted[key] = mini(MOST_USES, int(counted.get(key, 0)) + 1)


# -------------------------------------------------------------- duels --

## A DUEL BEGUN (API 3): [param site_key]'s duel action [param action] —
## its stake (the next price) and what it needs paid, the press counted
## unless it counts wins. The gold paid, −1 when no duel may begin
## ([method refusal]; nothing paid). The duel itself is the world screen's
## ([code]site_journey.gd[/code]), which saves right after this: a duel
## left unfinished is then a stake lost, and never one to try again free.
func duel_begin(player: AdventurePlayer, site_key: String, action: String) -> int:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "duel" or foe(String(entry.get("foe", ""))).is_empty() \
			or refusal(player, site_key, entry) != "":
		return -1
	var cost := price(player, site_key, entry)
	_pay(player, entry, cost)
	if String(entry.get("count", "press")) != "win":
		_count(player, site_key, action)
	return cost


## THE DUEL OVER: [param won] or not (a draw is not a win) — the branch's
## effects applied, a win counted for an action that counts wins, the
## result written in the journal under the plugin's own event
## (`<plugin>:duel`, never the hero's duel record). The pane to show: the
## branch's `result`, else the engine's sentence.
func duel_end(player: AdventurePlayer, site_key: String, action: String, won: bool, cost := 0) -> Dictionary:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "duel":
		return describe(player, site_key)
	var filled := values(player, site_key, entry, {"price": cost})
	if won and String(entry.get("count", "press")) == "win":
		_count(player, site_key, action)
	var branch: Dictionary = entry.get("win" if won else "lose", {})
	apply(player, site_key, branch.get("effects", []), filled)
	player.log_event(id + ":duel", say("site.duel_won_log" if won else "site.duel_lost_log", filled), {"site": id + ":" + site_key})
	var after := values(player, site_key, entry, {"price": cost})
	var lines := _lines(player, site_key, branch.get("result", []), after)
	return result_place(player, site_key, lines if not lines.is_empty() else [say("site.duel_won" if won else "site.duel_lost", after)])


# ------------------------------------------------------------- trades --

## The most a town pays for [param card] ([method CardShop.sell_range]): a
## place never sells it for less nor buys it for more, so no card bought in
## one and sold in the other makes gold.
static func town_price(card: String) -> int:
	return CardShop.sell_range(card).y


func _stock_key(site_key: String, entry: Dictionary, card: String) -> String:
	return "%s.%s#%08x" % [site_key, String(entry["id"]), AdventureSites.fnv(card)]


## How many more of [param card] a trade trades (−1: without end).
func stock_left(player: AdventurePlayer, site_key: String, entry: Dictionary, card: String) -> int:
	if not entry.has("stock"):
		return -1
	var counted: Variant = progress(player).get("uses", {})
	var traded := int(counted.get(_stock_key(site_key, entry, card), 0)) if counted is Dictionary else 0
	return maxi(0, int(entry["stock"]) - traded)


## What [param entry] (a `buy_card`) sells the hero now, `{card: gold}`:
## each card in stock they may hold one more of, at its price — never under
## [method town_price].
func buyable(player: AdventurePlayer, site_key: String, entry: Dictionary) -> Dictionary:
	var out := {}
	var rule := CardShop.classic_rule(player)
	var cards: Dictionary = entry.get("cards", {})
	for card: String in cards:
		if not CardRegistry.has_card(card) or stock_left(player, site_key, entry, card) == 0 \
				or not CardShop.classic_allows(rule, card):
			continue
		out[card] = maxi(int(cards[card]), town_price(card))
	return out


## What [param entry] (a `sell_card`) buys of the hero now, `{card: gold}`:
## each card they hold that is still wanted, at its price — never over
## [method town_price].
func sellable(player: AdventurePlayer, site_key: String, entry: Dictionary) -> Dictionary:
	var out := {}
	var cards: Dictionary = entry.get("cards", {})
	for card: String in cards:
		if held(player, card) < 1 or stock_left(player, site_key, entry, card) == 0:
			continue
		out[card] = mini(int(cards[card]), town_price(card))
	return out


## A CARD BOUGHT: [param card] of [param site_key]'s `buy_card` action in
## the bag for its price ([method buyable]), or why not — nothing paid then.
func buy_card(player: AdventurePlayer, site_key: String, action: String, card: String) -> Dictionary:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "buy_card":
		return describe(player, site_key)
	var why := refusal(player, site_key, entry)
	var offered := buyable(player, site_key, entry)
	if why == "" and not offered.has(card):
		why = say("site.no_stock")
	if why == "" and player.gold < int(offered[card]):
		why = say("site.no_gold", {"price": int(offered[card]), "gold": player.gold})
	if why != "":
		return result_place(player, site_key, [why])
	if not player.add_card(card):
		return result_place(player, site_key, [say("site.bag_full")])
	var cost := int(offered[card])
	player.gold -= cost
	return _traded(player, site_key, entry, card, cost, "bought")


## A CARD SOLD: one copy of [param card] (one in no deck first) for the
## gold of [param site_key]'s `sell_card` action ([method sellable]).
func sell_card(player: AdventurePlayer, site_key: String, action: String, card: String) -> Dictionary:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "sell_card":
		return describe(player, site_key)
	var why := refusal(player, site_key, entry)
	var wanted := sellable(player, site_key, entry)
	if why == "" and not wanted.has(card):
		why = say("site.nothing_to_sell")
	if why != "" or not take_card(player, card):
		return result_place(player, site_key, [why if why != "" else say("site.nothing_to_sell")])
	var cost := int(wanted[card])
	player.gold += cost
	return _traded(player, site_key, entry, card, cost, "sold")


func _traded(player: AdventurePlayer, site_key: String, entry: Dictionary, card: String, cost: int, word: String) -> Dictionary:
	_count(player, site_key, String(entry["id"]))
	if entry.has("stock"):
		_count_key(player, _stock_key(site_key, entry, card))
	var filled := values(player, site_key, {}, {"price": cost, "card": card})
	player.log_event("site", say("site.%s_log" % word, filled), {"card": card, "site": id + ":" + site_key})
	var lines := _lines(player, site_key, entry.get("result", []), filled)
	return result_place(player, site_key, lines if not lines.is_empty() else [say("site." + word, filled)])


## The hero's cards a copy may be made of, `{name: count}`: every card
## they hold, but under the Classic MTG rules none they hold every copy of
## the rules allow ([method CardShop.classic_rule]) — the wise man's rule
## for his copy.
static func copyable(player: AdventurePlayer) -> Dictionary:
	# Counted here, not by CardListPane.counted: this side never names the
	# world UI (the h5-1 rule).
	var counted := {}
	for row: Variant in player.cards:
		if row is Dictionary and String(row.get("card", "")) != "":
			counted[String(row["card"])] = int(counted.get(String(row["card"]), 0)) + 1
	var rule := CardShop.classic_rule(player)
	if rule.is_empty():
		return counted
	var out := {}
	for card_name in counted:
		if CardShop.classic_allows(rule, String(card_name)):
			out[card_name] = counted[card_name]
	return out


## Apply [param effects] in order for place [param site_key].
func apply(player: AdventurePlayer, site_key: String, effects: Array, filled := {}) -> void:
	for effect in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		var state := _state(player)
		match key:
			"set_flag":
				if not value in state["flags"]: (state["flags"] as Array).append(String(value))
			"clear_flag": (state["flags"] as Array).erase(String(value))
			"gold": player.gold = maxi(0, player.gold + int(value))
			"food": player.food = maxi(0, player.food + int(value))
			"spawn_dungeon": spawn(player, String(value), site_key)
			"log_clue": player.log_clue(say(String(value["text"]), values(player, site_key, {}, filled)), "clue")
			"log_event":
				# UNDER THE PLUGIN'S OWN NAME, `<plugin>:<event>` (the campaign of
				# 2026-11-22): written as the plugin said it, "duel" counted as a
				# lost duel on the hero's page, "quest" as a quest, "saved",
				# "freed" and "treasure" as theirs — from a free button, without
				# end. No id holds a colon, so none of the game's events can be
				# named. A line an older game wrote is shown as it always was.
				var words := say(String(value["text"]), values(player, site_key, {}, filled))
				if bool(value.get("done", false)): player.log_event(id + ":" + String(value["event"]), words, {"done": true})
				else: player.log_event(id + ":" + String(value["event"]), words)
			# API 3.
			"counter":
				if not state.get("counters") is Dictionary:
					state["counters"] = {}
				var name := String(value["name"])
				state["counters"][name] = clampi(int(value["set"]) if value.has("set") else counter(player, name) + int(value.get("add", 0)), 0, MOST_USES)
			"amulet":
				var color := String(value["color"])
				var have := int(player.amulets.get(color, 0))
				var count := int(value.get("count", 1))
				# Never over the cap by this gift, never under what is carried.
				player.amulets[color] = maxi(have, mini(MOST_AMULETS, have + count)) if count > 0 else maxi(0, have + count)
			"give_card": player.add_card(String(value))
			"next_duel":
				# One gift at a time, as 1997's one slot ([method
				# AdventurePlayer.duel_gift_waiting]; asked before paying too).
				if not player.duel_gift_waiting():
					if value.has("life"): player.next_duel_life = clampi(int(value["life"]), 1, 20)
					elif bool(value.get("first_move", false)): player.next_duel_first_move = true
					elif value.has("card"): player.next_duel_card = String(value["card"])
			"reveal_map": _reveal(player, site_key, value)
			"world_magic":
				# As the seller's own sale ([method WorldMagicShop.buy]): the
				# hero's, and sold nowhere any more — on this land, and on the
				# mainland's saved map when the hero is away from it.
				var magic := String(value)
				var index := AdventurePlayer.WORLD_MAGICS.find(magic)
				if index >= 0 and not player.owns(magic):
					player.world_magics.append(magic)
					if index < player.world.world_magic_sites.size():
						player.world.world_magic_sites[index] = 0
					for region: Variant in player.regions:
						var saved: Variant = player.regions[region].get("world", {}).get("world_magic_sites") if player.regions[region] is Dictionary else null
						if saved is Array and index < (saved as Array).size():
							saved[index] = 0
					player.log_event("magic", "Bought WM: %s" % magic)
			"mana_link":
				var town := nearest_town(player, site_key, true)
				if town >= 0:
					TownStatus.put(player.world, town, TownStatus.LINKED)
			"life_bonus":
				player.life_bonus = clampi(player.life_bonus + int(value), 0, AdventurePlayer.LIFE_BONUS_MOST)
			# "teleport" moves the hero on the world screen (site_journey.gd).


# ----------------------------------------------- towns and journeys --

## THE TOWN OR CITY NEAREST PLACE [param site_key] on this land (its slot,
## −1 for none) — with [param linkable] the nearest a mana link can be made
## with: the land has mana links, the town has none, no wizard holds it and
## none besieges it (a siege's own count of the link is never disturbed).
func nearest_town(player: AdventurePlayer, site_key: String, linkable := false) -> int:
	var world := player.world
	if linkable and not AdventureExpansions.mana_links_allowed(world):
		return -1
	var here := _here(player, site_key)
	var besieged := WorldStatus.siege_town(player) if linkable else -1
	var best := -1
	var distance := INF
	for slot in world.sites.size():
		if not TownStatus.is_town(world, slot):
			continue
		if linkable and (TownStatus.has(world, slot, TownStatus.LINKED) or TownStatus.ruled(world, slot) or slot == besieged):
			continue
		var gap := here.distance_squared_to(Vector2i(int(world.sites[slot]["x"]), int(world.sites[slot]["y"])))
		if gap < distance:
			distance = gap
			best = slot
	return best


## The teleport [param entry] ends with, {} for none.
static func teleport_of(entry: Dictionary) -> Dictionary:
	for effect: Dictionary in entry.get("effects", []):
		if effect.has("teleport"):
			return effect["teleport"]
	return {}


## The tile a teleport's `to` names on this land, (−1, −1) for none here:
## the nearest town or city, the land's start, another place of this plugin
## standing here, a dungeon of it raised here.
func teleport_target(player: AdventurePlayer, site_key: String, to: String) -> Vector2i:
	var world := player.world
	if to == "nearest_town":
		var town := nearest_town(player, site_key)
		return Vector2i(int(world.sites[town]["x"]), int(world.sites[town]["y"])) if town >= 0 else Vector2i(-1, -1)
	if to == "start":
		return world.start_tile()
	if to.begins_with("place:"):
		var placed: Variant = world.expansion.get(AdventureSites.KEY, {})
		var point: Variant = (placed as Dictionary).get(id + ":" + to.trim_prefix("place:")) if placed is Dictionary else null
		return Vector2i(int(point[0]), int(point[1])) if AdventureRegions.valid_point(point) else Vector2i(-1, -1)
	if to.begins_with("dungeon:"):
		var index := dungeon_index(player, to.trim_prefix("dungeon:"))
		return Vector2i(int(world.encounters[index].get("x", -1)), int(world.encounters[index].get("y", -1))) if index >= 0 else Vector2i(-1, -1)
	return Vector2i(-1, -1)


## WHERE A TELEPORT SETS THE HERO DOWN ([param value] its `{to}`): the free
## tile nearest its target ([method teleport_target]) within three tiles —
## beside it, never on it, so its pane does not open by itself (the land's
## start itself when it is free) — land of the hero's own landmass
## ([method RegionGeography.component]: never across water), with no town,
## dungeon, place, lair or portal on it and not the hero's own.
## (−1, −1) when the target is not on this land or no such tile is.
func teleport_tile(player: AdventurePlayer, site_key: String, value: Dictionary) -> Vector2i:
	var world := player.world
	var to := String(value.get("to", ""))
	var target := teleport_target(player, site_key, to)
	if target.x < 0:
		return Vector2i(-1, -1)
	var key := [world.get_instance_id(), player.tile()]
	if key != _landmass_key:
		_landmass_key = key
		_landmass = {}
		for tile in RegionGeography.component(world, player.tile()):
			_landmass[tile] = true
	var taken := {}
	for tile in AdventureSites.blocked_tiles(player):
		taken[tile] = true
	for point: Variant in AdventureSites.points(world):
		taken[Vector2i(int(point[0]), int(point[1]))] = true
	var options: Array[Vector2i] = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var tile := target + Vector2i(dx, dy)
			if tile == target and to != "start":
				continue
			if not _landmass.has(tile) or taken.has(tile) or AdventureExpansions.marker(world, tile) != "" \
					or world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.DUNGEON) != 0:
				continue
			options.append(tile)
	if options.is_empty():
		return Vector2i(-1, -1)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var far_a := a.distance_squared_to(target)
		var far_b := b.distance_squared_to(target)
		return far_a < far_b if far_a != far_b else (a.y < b.y if a.y != b.y else a.x < b.x))
	return options[0]


## THE MAP UNCOVERED around the place (or a raised dungeon of the plugin's,
## `around: "dungeon:<key>"`; nothing while it is not raised), every tile
## within `radius` of it.
func _reveal(player: AdventurePlayer, site_key: String, value: Dictionary) -> void:
	var around := String(value.get("around", "place"))
	var center := _here(player, site_key)
	if around.begins_with("dungeon:"):
		var index := dungeon_index(player, around.trim_prefix("dungeon:"))
		if index < 0:
			return
		center = Vector2i(int(player.world.encounters[index].get("x", 0)), int(player.world.encounters[index].get("y", 0)))
	var world := player.world
	var radius := int(value.get("radius", 4))
	var seen := false
	for y in range(maxi(0, center.y - radius), mini(ShandalarWorld.TILES, center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(ShandalarWorld.TILES, center.x + radius + 1)):
			if Vector2(x - center.x, y - center.y).length() > radius + 0.5:
				continue
			var at := y * ShandalarWorld.PAGE_WIDTH + x
			if at < world.page.size() and world.page[at] & ShandalarWorld.EXPLORED == 0:
				world.page[at] = world.page[at] | ShandalarWorld.EXPLORED
				seen = true
	if seen:
		world.touch_page()


## Why the effects of [param entry] cannot be applied on this land, ""
## when they can: a dungeon to raise and no slot or tile left for it.
func _spawn_problem(player: AdventurePlayer, entry: Dictionary, site_key := "") -> String:
	var effects: Array = effects_now(player, site_key, entry)["effects"] if site_key != "" else entry.get("effects", [])
	for effect in effects:
		if effect.keys()[0] != "spawn_dungeon":
			continue
		var key := String(effect["spawn_dungeon"])
		if dungeon_state(player, key) == "open":
			continue
		if player.world.encounters.size() >= WorldClues.MOST_SLOTS or _dungeon_tile(player, key, site_key).x < 0:
			return say("site.no_room")
	return ""


# ------------------------------------------------------------ dungeons --

## THE TILE PLACE [param site_key] STANDS ON in [param player]'s land
## ([member AdventureSites.KEY]), else the hero's — a dungeon it raises is
## measured from the place, wherever the hero stands.
func _here(player: AdventurePlayer, site_key := "") -> Vector2i:
	var placed: Variant = player.world.expansion.get(AdventureSites.KEY, {})
	var point: Variant = (placed as Dictionary).get(id + ":" + site_key) if placed is Dictionary else null
	if site_key != "" and AdventureRegions.valid_point(point):
		return Vector2i(int(point[0]), int(point[1]))
	return player.tile()


## The landmarks a raised dungeon keeps its air from ([method _airy]), read
## once for a land's tiles: `slots`, every castle and dungeon of the land
## (1997's, known or not, and each raised before), and `towns`, its towns
## and cities — 1997's own gap of [constant DUNGEON_GAP] for a dungeon it
## places; `near`, the villages, every place and anchorage the land keeps,
## the lairs and Arzakon's portal, which it does not stand beside.
func _dungeon_air(player: AdventurePlayer, kept: Dictionary) -> Dictionary:
	var world := player.world
	var slots: Array[Vector2i] = []
	for slot: Variant in world.encounters:
		if slot is Dictionary and (slot as Dictionary).has("x") and (slot as Dictionary).has("y"):
			slots.append(Vector2i(int(slot["x"]), int(slot["y"])))
	var towns: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	for site: Dictionary in world.sites:
		var kind := int(site.get("type", 0))
		var at := Vector2i(int(site.get("x", 0)), int(site.get("y", 0)))
		if kind == ShandalarWorld.TOWN or kind == ShandalarWorld.CITY:
			towns.append(at)
		elif kind > 0:
			near.append(at)
	for tile: Vector2i in kept:
		near.append(tile)
	var portal := FinalBattle.portal_tile_of(player)
	if portal.x >= 0:
		near.append(portal)
	return {"slots": slots, "towns": towns, "near": near}


## Whether [param tile] has a dungeon's air of [param air] ([method
## _dungeon_air]): 1997's distance ([method WorldGenerator.distance]) of
## [constant DUNGEON_GAP] or more from every town, city, castle and
## dungeon, and no other landmark on a tile beside it.
static func _airy(tile: Vector2i, air: Dictionary) -> bool:
	for group in ["slots", "towns"]:
		for at: Vector2i in air[group]:
			if WorldGenerator.distance(at.x - tile.x, at.y - tile.y) < DUNGEON_GAP:
				return false
	for at: Vector2i in air["near"]:
		if absi(at.x - tile.x) <= 1 and absi(at.y - tile.y) <= 1:
			return false
	return true


## The tile dungeon [param key] would rise on: land of the place's own
## land, one a moved dungeon could take ([method DungeonDoors.takes_dungeon])
## and away from every place ([method AdventureSites.points]) and every
## lair, its distance from the place within the dungeon's `distance` (else
## the nearest such tile past `min`), drawn on the plugin's dice ([method
## AdventureSites.dice_for]) for this land, key and raising. (−1, −1) for none.
##
## It keeps its air too ([method _airy], 0.70.9; the owner: *"make sure the
## newly placed dungeon does not overlap with other landmarks!!"*): a tile
## crowded by a landmark is taken only when the distance asked for holds no
## airy one. Where every tile that could be drawn is airy the draw is the
## one it always was.
func _dungeon_tile(player: AdventurePlayer, key: String, site_key := "") -> Vector2i:
	var world := player.world
	var info := dungeon(key)
	var here := _here(player, site_key)
	var distance: Dictionary = info.get("distance", {})
	var least := float(distance.get("min", 6))
	var most := float(distance.get("max", 24))
	var portal := FinalBattle.portal_tile_of(player)
	# The tiles the land's places and anchorages keep, read once for every
	# tile asked (the review of 2026-11-21) — the places' own among them.
	var kept := DungeonDoors.kept_points(world)
	for point: Variant in AdventureSites.points(world):
		kept[Vector2i(int(point[0]), int(point[1]))] = true
	# A lair stands on its tile until it is explored, and its pane is asked
	# before a dungeon's: never under one (as no place is, [method
	# AdventureSites.blocked_tiles]).
	for creature: Variant in player.monsters:
		if creature is Dictionary and String(creature.get("kind", "")) == "lair" \
				and AdventurePlayer._is_number(creature.get("x")) and AdventurePlayer._is_number(creature.get("y")):
			kept[Vector2i(int(creature["x"]) / 32, int(creature["y"]) / 32)] = true
	var air := _dungeon_air(player, kept)
	var inside: Array[Vector2i] = []
	var beyond: Array[Vector2i] = []
	var crowded_inside: Array[Vector2i] = []
	var crowded_beyond: Array[Vector2i] = []
	for tile in RegionGeography.component(world, here):
		if kept.has(tile) or not DungeonDoors.takes_dungeon(world, tile, player.tile(), portal, kept):
			continue
		var far := tile.distance_to(here)
		if far < least:
			continue
		var airy := _airy(tile, air)
		if far <= most:
			(inside if airy else crowded_inside).append(tile)
		else:
			(beyond if airy else crowded_beyond).append(tile)
	# No airy tile at the distance asked for: a crowded one there, before
	# an airy one farther off (the distance is the plugin's word).
	if inside.is_empty():
		inside = crowded_inside
	if beyond.is_empty():
		beyond = crowded_beyond
	if inside.is_empty() and not beyond.is_empty():
		beyond.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(here) < b.distance_squared_to(here))
		inside = beyond.slice(0, 8)
	if inside.is_empty():
		return Vector2i(-1, -1)
	var raised := int(_state(player)["uses"].get("dungeon:" + key, 0)) if player.sites.has(id) else 0
	var dice := AdventureSites.dice_for(world, int(file().get("salt", 0)), "%s:%s:%s:%d" % [id, land(player), key, raised])
	return inside[dice.below(inside.size())]


## DUNGEON [param key] RAISED on [param player]'s land — unless it is open
## there already: a new encounter slot (after the 1997 ones; [constant
## WorldClues.MOST_SLOTS] at most) on [method _dungeon_tile]'s tile, its
## color, size and rules the plugin's, its treasure the plugin's cards (by
## name, as cards put back in a dungeon are kept, [constant
## WorldClues.LEFT_CARDS]), everything about it known (where, its creatures,
## its rules), its name the plugin's ([method WorldNames.dungeon_name]). The
## slot, or −1 when none could be raised.
func spawn(player: AdventurePlayer, key: String, site_key := "") -> int:
	var info := dungeon(key)
	if info.is_empty() or player == null or player.world == null:
		return -1
	var open := dungeon_index(player, key)
	if open >= 0 and WorldClues.holds_cards(player.world.encounters[open]):
		return open
	var world := player.world
	if world.encounters.size() >= WorldClues.MOST_SLOTS:
		return -1
	var tile := _dungeon_tile(player, key, site_key)
	if tile.x < 0:
		return -1
	# Slots 0–4 are the wizards' castles on every land (an island keeps them
	# empty): a raised dungeon never takes one.
	while world.encounters.size() < DungeonDoors.CASTLES:
		world.encounters.append({"x": 0, "y": 0, "cards": [], "clues": 0})
	var state := _state(player)
	var raised := int(state["uses"].get("dungeon:" + key, 0))
	var dice := AdventureSites.dice_for(world, int(file().get("salt", 0)), "%s:%s:%s:%d:color" % [id, land(player), key, raised])
	var color_name := String(info.get("color", "random"))
	var color := COLORS.find(color_name) + 1 if color_name in COLORS else dice.below(5) + 1
	var rules := 0
	for rule in info.get("rules", []):
		rules |= int(RULE_BITS.get(String(rule), 0))
	var cards: Array[String] = []
	for card in info.get("cards", []):
		cards.append(String(card))
	var index := world.encounters.size()
	world.encounters.append({"x": tile.x, "y": tile.y, "town": _nearest_town(world, tile), "color": color,
		"monster_flags": DungeonBoard.LARGE if String(info.get("size", "small")) == "large" else 0,
		"rules": rules, "card_in_effect": -1, "cards": [], WorldClues.LEFT_CARDS: cards,
		"clues": WorldClues.LOCATION | WorldClues.CREATURES | WorldClues.RULES,
		WorldClues.RAISED: id + ":" + key})
	world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] |= ShandalarWorld.DUNGEON
	world.touch_page()
	var names: Dictionary = world.expansion.get("dungeon_names", {}) if world.expansion.get("dungeon_names") is Dictionary else {}
	names[str(index)] = String(info.get("name", key))
	world.expansion["dungeon_names"] = names
	state["dungeons"][land(player) + ":" + key] = index
	state["uses"]["dungeon:" + key] = raised + 1
	world.appearance_revision += 1
	return index


## The town or city nearest [param tile] (a dungeon's clue says where it
## lies from one), 0 when the land has none.
static func _nearest_town(world: ShandalarWorld, tile: Vector2i) -> int:
	var best := 0
	var distance := INF
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		if int(site["type"]) < ShandalarWorld.VILLAGE or int(site["type"]) >= ShandalarWorld.CASTLE:
			continue
		var gap := tile.distance_squared_to(Vector2i(int(site["x"]), int(site["y"])))
		if gap < distance:
			distance = gap
			best = slot
	return best


# -------------------------------------------------------------- tasks --

## THE PLUGIN'S ROWS FOR THE TASKS PANE on [param player]'s land (API 3,
## `tasks`): each task whose `when` holds — one `at` a place only on a land
## the place stands on —, done once its `done_when` holds; its tile the
## place's, or the dungeon's once raised ([method AdventureTasks.row]).
func task_rows(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tasks: Dictionary = file().get("tasks", {})
	for key: String in tasks:
		var task: Dictionary = tasks[key]
		var at := String(task.get("at", ""))
		var site_key := at.trim_prefix("place:") if at.begins_with("place:") else ""
		var tile := Vector2i(-1, -1)
		var more := {}
		if site_key != "":
			var placed: Variant = player.world.expansion.get(AdventureSites.KEY, {})
			var point: Variant = (placed as Dictionary).get(id + ":" + site_key) if placed is Dictionary else null
			if not AdventureRegions.valid_point(point):
				continue
			tile = Vector2i(int(point[0]), int(point[1]))
		elif at.begins_with("dungeon:"):
			var index := dungeon_index(player, at.trim_prefix("dungeon:"))
			if index >= 0:
				tile = Vector2i(int(player.world.encounters[index].get("x", -1)), int(player.world.encounters[index].get("y", -1)))
			more["dungeon"] = dungeon_word(player, at.trim_prefix("dungeon:"))
		if not holds(player, site_key, task.get("when", [])):
			continue
		var filled := values(player, site_key, {}, more, task)
		var row := AdventureTasks.row("site:%s:%s" % [id, key], land(player), say(String(task["title"]), filled),
			say(String(task["text"]), filled), tile)
		var done_when: Array = task.get("done_when", [])
		if not done_when.is_empty() and holds(player, site_key, done_when):
			AdventureTasks.completed(row, say(String(task.get("done", task["text"])), filled))
		out.append(row)
	return out


## The panes' buttons (UI side, [code]site_journey.gd[/code]).
func act(screen: Node, action: String, place: Dictionary) -> bool:
	if not action.begins_with(id + "_"):
		return false
	return bool(_journey().call("act", self, screen, action, place))

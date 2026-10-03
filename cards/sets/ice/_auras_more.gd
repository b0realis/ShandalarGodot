extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")
const S := preload("res://cards/sets/ice/_snow.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Aggression":
			c.enchants(TargetSpec.creature("target non-Wall creature", _nonwall))
			c.static_ability(StaticAbility.new(A._host_keywords.bind([Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE]), "First strike and trample.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _aggression, "Destroy enchanted creature if it did not attack this turn.", _host_end).capturing(A._host_context))
		"Brand of Ill Omen":
			c.enchants(TargetSpec.creature()).bans_playing(_brand_ban)
		"Prismatic Ward", "Chromatic Armor":
			c.enchants(TargetSpec.creature()).as_it_enters(_choose_color_enter)
			c.static_ability(StaticAbility.new(_ward, "Prevent damage from the chosen color to enchanted creature."))
			if c.card_name == "Chromatic Armor":
				c.with_enters_counters("sleight", 1)
				c.activated(F._ability("{X}", false, F.Action.new(_chromatic, "add a sleight counter and choose a color")).with_x_condition(_sleight_x))
		"Caribou Range":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land you control", _land).with_source_filter(F._own))
			c.static_ability(StaticAbility.new(_caribou_land.bind(F._ability("{W}{W}", true, CreateTokenEffect.new("Caribou", 0, 1, Mtg.ManaColor.W, "caribou"))), "Enchanted land can create Caribou.").changing_abilities())
			c.activated(F._ability("", false, GainLifeEffect.new(1)).with_sacrifice_of("Caribou token", _caribou))
		"Earthlore":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land you control", _land).with_source_filter(F._own))
			var pump := PumpEffect.new(1, 2)
			pump.target_spec = TargetSpec.creature("target blocking creature").with_game_filter(F._blocking)
			var ability := F._ability("", false, pump).only_if(_untapped_host)
			ability.on_cost_paid = _tap_host
			c.activated(ability)
		"Snowblind":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_snowblind, "Snow lands reduce the enchanted creature's stats, leaving at least 1 toughness."))
		"Cloak of Confusion":
			c.enchants(TargetSpec.creature("target creature you control").with_source_filter(F._own))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _cloak, "May forgo combat damage to make the defender discard at random.", F._farrel_unblocked.bind(true)).capturing(F._farrel_context.bind(true)))
		_: return false
	return true

static func _nonwall(i: CardInstance) -> bool: return not i.has_subtype("wall")
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _caribou(i: CardInstance) -> bool: return i.is_token and i.has_subtype("caribou")
static func _host_end(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and i.controller_id == int(e.data.player) and not i.attacked_this_turn
static func _aggression(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A._trigger_host(g, s)
	if i != null and not i.attacked_this_turn: g.destroy(i)
static func _brand_ban(g: MtgGame, pid: int, data: CardData) -> bool:
	if not data.is_creature(): return false
	for s in g.all_battlefield():
		if s.data.card_name != "Brand of Ill Omen" or s.cur_abilities_silenced: continue
		var i := A.host(g, s)
		if i != null and i.controller_id == pid: return true
	return false
static func _choose_color_enter(g: MtgGame, s: CardInstance, pid: int, preferred := 0) -> void:
	var counts := {}
	for i in g.players[1 - pid].battlefield:
		for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]:
			if (i.cur_colors & color) != 0: counts[color] = int(counts.get(color, 0)) + 1
	var best := Mtg.ManaColor.R
	for color in counts:
		if int(counts[color]) > int(counts.get(best, 0)): best = color
	if preferred != 0: best = preferred
	g._rec(s, &"memory")
	s.memory["ward_color"] = g.agents[pid].choose_color(g, pid, s.data.card_name + ": choose a color", best)
static func _ward(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null or not s.memory.has("ward_color"): return
	i.cur_damage_immunity.append({"desc": s.data.card_name,
		"filter": _source_color.bind(int(s.memory.ward_color))})
static func _source_color(g: MtgGame, source: CardInstance, color: int) -> bool: return (g.damage_source_colors(source) & color) != 0
static func _sleight_x(_g: MtgGame, s: CardInstance, x: int, _targets: Array) -> String:
	return "" if x == int(s.counters.get("sleight", 0)) else "X must equal the number of sleight counters"
static func _chromatic(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not preload("res://cards/sets/ice/_creatures.gd").same_activation(g, s) or not g.is_present(s): return   # CR 702.26e
	g.add_counters(s, "sleight")
	var preferred := 0
	var i := A.host(g, s)
	if i != null:
		for item in g.stack:
			if item.card == null or item.controller == pid: continue
			var aimed := false
			for ref in item.targets:
				if not ref.is_player and ref.instance_id == i.id: aimed = true
			if not aimed: continue
			var intent := EffectIntent.read(item.effects)
			if intent.damage <= 0 and not intent.damage_uses_x: continue
			for color in Mtg.WUBRG:
				if (g.damage_source_colors(item.card) & color) != 0: preferred = color
	_choose_color_enter(g, s, pid, preferred)
	g.recalculate()
static func _caribou_land(g: MtgGame, s: CardInstance, ability: ActivatedAbility) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_activated_abilities.append(ability)
static func _untapped_host(g: MtgGame, s: CardInstance) -> String:
	var i := A.host(g, s)
	return "" if i != null and not i.tapped else "Enchanted land must be untapped"
static func _tap_host(g: MtgGame, s: CardInstance, _cost: Dictionary) -> void:
	var i := A.host(g, s)
	if i != null: g.tap_permanent(i)
static func _snowblind(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	var who := 1 - i.controller_id if g.combat.attackers.has(i.id) else i.controller_id
	var n := S.snow_count(g, who)
	i.cur_power -= n
	i.cur_toughness -= mini(n, maxi(0, i.cur_toughness - 1))
static func _cloak(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i: CardInstance = ctx.attacker
	var who := int(ctx.controller)
	# Phased out: it can't be made to assign no damage, so "if you do"
	# fails and nobody discards (CR 702.26b).
	if not g.is_present(i) or i.layer_timestamp != int(ctx.timestamp): return
	if g.agents[who].choose_yes_no(g, who, "Cloak of Confusion: forgo combat damage to make the opponent discard?", i.cur_power < 3 and not g.players[1 - who].hand.is_empty()):
		F._no_assignment(g, s, i.id)
		g.discard_random(1 - who, 1)

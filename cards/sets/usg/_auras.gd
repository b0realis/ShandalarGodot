extends RefCounted
## Urza's Saga (_auras, Pack 10). Auras: enchant a permanent and change it while attached.
##
## The shared Aura helpers live in cards/sets/mir/_auras.gd (A): statics read
## the host through A.host (present, not phased out); keyword grants are
## layer-6 statics (changing_abilities, CR 613.7); pumps are layer 7c; an
## Aura's activated ability names the creature it enchanted when it was
## activated (A.HostPump, A.HostRegenerate — the cost record keeps it, so a
## sacrificed Aura still knows, CR 608.2h); a triggered ability names
## "enchanted creature" as it was when it triggered (A.host_context /
## A.trigger_host, CR 400.7) and still resolves after the Aura has left
## (CR 603.6).
##
## THE SELF-RETURNING AURAS (the block's eleven: Brilliant Halo, Launch,
## Despondency, Fiery Mantle, Fortitude, Spreading Algae here; Cessation,
## Slow Motion, Sleeper's Guile, Sluggishness and Rancor in ulg/_auras.gd,
## which preloads [method returns_home]). "When this Aura is put into a
## graveyard from the battlefield, return it to its owner's hand" is a
## leaves-the-battlefield trigger (CR 603.6c, 603.10a): LEAVES_BATTLEFIELD
## is dispatched after the card has arrived in its new zone, with the
## departing card listening, so `zone == GRAVEYARD` tells the graveyard from
## a bounce or an exile — an Aura exiled instead (Forbidden Crypt) never
## triggers. An Aura shed by state-based actions (host gone or illegal,
## CR 704.5m) goes to the graveyard from the battlefield too, so it comes
## back: Rancor's loop. The trigger captures the card's graveyard entry and
## returns only that object (CR 400.7): one that left the graveyard and
## came back in response is a new object and stays.
##
## - Pariah: a static damage REDIRECT (engine/damage_replacements.gd,
##   CR 614.1a/616.1) — damage to the AURA'S controller is dealt to the
##   enchanted creature, whoever controls that creature.
## - Confiscate: Control Magic's steal (CardData.steals_control) on any
##   permanent; an Aura it steals stays on what it enchants.
## - Hermetic Study grants the HOST "{T}: This creature deals 1 damage to
##   any target." (its controller activates it, summoning sickness applies,
##   CR 302.6); Fiery Mantle's and Shiv's Embrace's {R} pumps are the
##   AURA'S abilities (A.HostPump, the `pump_host` AI role).
## - Pendrell Flux grants the host an upkeep TRIGGER (layer 6,
##   granting_triggers): its controller pays the creature's mana cost or
##   sacrifices it. A creature with no mana cost (a token) cannot pay
##   (CR 118.6), so it is sacrificed; a printed {0} is paid by saying yes.
## - Vampiric Embrace: Sengir Vampire's reading of the dying creature's
##   `damage_origins` (the host's id and timestamp, CR 400.7); the counter
##   goes on the creature the Aura enchanted when the ability triggered.
## - Destructive Urge, Venomous Fangs: DAMAGE_DEALT with the host as
##   source (one event per victim); the land is sacrificed by the damaged
##   player, of their choice; Fangs destroys the creature that was dealt
##   damage if it is still that object.
## - Fertile Ground: a MANA trigger (CR 605.1b), Wild Growth's shape, whose
##   one mana of any color is chosen by the land's controller. Its public
##   description (`mana_bonus_color = ManaPlanner.BONUS_ANY_COLOR`) makes
##   MtgGame.tap_for_mana ask that colour with the rest of the activation,
##   before anything is paid (held for a human seat, Pack 10 E8), and hand
##   it over as the TAPPED_FOR_MANA event's `bonus_colors[<this Aura's id>]`.
##   A dispatch that carries no answer falls back to asking from inside the
##   trigger (DecisionAgent.choose_color) with the same hint: the land's own
##   colour — what the mana planner counted.
## - Spreading Algae: "Enchant Swamp" reads the LIVE subtype, so a Swamp
##   that stops being one sheds the Algae (and it comes home).
## tests/cards/test_pack_10_B7_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

const RETURN_TEXT := "When this Aura is put into a graveyard from the battlefield, return it to its owner's hand."
const FLUX_TEXT := "At the beginning of your upkeep, sacrifice this creature unless you pay its mana cost."

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Brilliant Halo":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 2), "Enchanted creature gets +1/+2."))
			returns_home(c)
		"Pariah":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_pariah,
				"All damage that would be dealt to you is dealt to enchanted creature instead."))
		"Serra's Embrace":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 2), "Enchanted creature gets +2/+2."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE]),
				"Enchanted creature has flying and vigilance.").changing_abilities())
		"Cloak of Mists":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.UNBLOCKABLE]),
				"Enchanted creature can't be blocked.").changing_abilities())
		"Confiscate":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent")).steals_control()
		"Hermetic Study":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.grant_ability.bind(ActivatedAbility.new("", true,
				[DamageEffect.new(1).any_target()], "{T}: This creature deals 1 damage to any target.")),
				"Enchanted creature has \"{T}: This creature deals 1 damage to any target.\"").changing_abilities())
		"Launch":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
			returns_home(c)
		"Pendrell Flux":
			c.enchants(TargetSpec.creature())
			var flux := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _flux_upkeep, FLUX_TEXT,
				F._your_upkeep).capturing(F._source_context)
			c.static_ability(StaticAbility.new(A.grant_trigger.bind(flux),
				"Enchanted creature has \"" + FLUX_TEXT + "\"").changing_abilities() \
				.granting_triggers([Mtg.EventType.UPKEEP_START]))
		"Zephid's Embrace":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 2), "Enchanted creature gets +2/+2."))
			c.static_ability(StaticAbility.new(_flying_and_shroud,
				"Enchanted creature has flying and shroud.").changing_abilities())
		"Despondency":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(-2, 0), "Enchanted creature gets -2/-0."))
			returns_home(c)
		"Parasitic Bond":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _parasitic_bond,
				"At the beginning of the upkeep of enchanted creature's controller, this Aura deals 2 damage to that player.",
				host_controllers_upkeep))
		"Vampiric Embrace":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 2), "Enchanted creature gets +2/+2."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _vampiric_feed,
				"Whenever a creature dealt damage by enchanted creature this turn dies, put a +1/+1 counter on that creature.",
				_host_wounded_it).capturing(A.host_context))
		"Bravado":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_bravado, "Enchanted creature gets +1/+1 for each other creature you control."))
		"Destructive Urge":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _destructive_urge,
				"Whenever enchanted creature deals combat damage to a player, that player sacrifices a land of their choice.",
				_host_hit_player_in_combat).capturing(_victim_context))
		"Fiery Mantle":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("{R}", false, [A.HostPump.new(1, 0)],
				"{R}: Enchanted creature gets +1/+0 until end of turn."))
			returns_home(c)
		"Reflexes":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FIRST_STRIKE]),
				"Enchanted creature has first strike.").changing_abilities())
		"Shiv's Embrace":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 2), "Enchanted creature gets +2/+2."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
			c.activated(ActivatedAbility.new("{R}", false, [A.HostPump.new(1, 0)],
				"{R}: Enchanted creature gets +1/+0 until end of turn."))
		"Blanchwood Armor":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(per_land.bind("forest", 1, 1),
				"Enchanted creature gets +1/+1 for each Forest you control."))
		"Fertile Ground":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))
			var bonus := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _fertile_ground,
				"Whenever enchanted land is tapped for mana, its controller adds an additional one mana of any color.",
				host_tapped).as_mana_trigger()
			# The public description (ManaPlanner._bonus_triggers): the
			# enchanted land makes one more mana of ANY colour — a question
			# tap_for_mana asks the land's controller before paying (E8); the
			# planner counts it as the land's own colour, the question's hint.
			bonus.mana_bonus_subtype = ManaPlanner.BONUS_ENCHANTED_LAND
			bonus.mana_bonus_color = ManaPlanner.BONUS_ANY_COLOR
			bonus.mana_bonus_amount = 1
			c.triggered(bonus)
		"Fortitude":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("", false, [A.HostRegenerate.new()],
				"Sacrifice a Forest: Regenerate enchanted creature.").with_sacrifice_of("Forest", _forest))
			returns_home(c)
		"Gaea's Embrace":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(3, 3), "Enchanted creature gets +3/+3."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.TRAMPLE]),
				"Enchanted creature has trample.").changing_abilities())
			c.activated(ActivatedAbility.new("{G}", false, [A.HostRegenerate.new()],
				"{G}: Regenerate enchanted creature."))
		"Spreading Algae":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Swamp", _swamp))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _algae,
				"When enchanted land becomes tapped, destroy it.", host_tapped).capturing(A.host_context))
			returns_home(c)
		"Venomous Fangs":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _venomous_fangs,
				"Whenever enchanted creature deals damage to a creature, destroy the other creature.",
				_host_hit_creature).capturing(_victim_context))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --
# Preloaded by ulg/_auras.gd and uds/_auras.gd.

## "When this Aura is put into a graveyard from the battlefield, return it
## to its owner's hand." (see the file note).
static func returns_home(c: CardData) -> void:
	c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _home, RETURN_TEXT,
		to_graveyard_from_battlefield).capturing(grave_context))

## The departing card itself, now in a graveyard (2ed/lich.gd's reading).
static func to_graveyard_from_battlefield(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s and s.zone == Mtg.Zone.GRAVEYARD

## The graveyard object that triggered (CR 400.7) and the seat that
## controlled the Aura as it left (CR 603.3a).
static func grave_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	out["entry"] = s.graveyard_entry
	out["controller"] = int(e.data.get("from_controller", s.controller_id))
	return out

static func _home(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.trigger_context(s).get("entry", -1)):
		g.return_from_graveyard_to_hand(s)

## "At the beginning of the upkeep of enchanted creature's controller".
static func host_controllers_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and i.controller_id == int(e.data.get("player", -1))

## "Whenever enchanted land is tapped for mana" / "becomes tapped".
static func host_tapped(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var tapped: CardInstance = e.data.get("instance")
	return tapped != null and s.attached_to != -1 and tapped.id == s.attached_to

## The Aura's counters of [param kind] as the ability resolves: live while
## it is the object that triggered, else as it last existed on the
## battlefield (CR 608.2h).
static func aura_counters(g: MtgGame, s: CardInstance, kind: String) -> int:
	var counters: Dictionary = s.counters if F._same_trigger_object(g, s) else s.last_counters
	return int(counters.get(kind, 0))

## "At the beginning of your upkeep, you may put a <kind> counter on this
## Aura." — the Aura's controller as it triggered decides; only the very
## object that triggered gets it (CR 400.7).
static func may_add_counter(g: MtgGame, s: CardInstance, _e: GameEvent, kind: String) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := A.pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "%s: put a %s counter on it?" % [s.data.card_name, kind],
			may_counter_hint(g, s, pid, kind)):
		g.add_counters(s, kind)

## Hint, public state only: yes — each counter is the Aura's only growth —
## except an infection counter on an Aura whose creature we control.
static func may_counter_hint(g: MtgGame, s: CardInstance, pid: int, kind: String) -> bool:
	if kind != "infection": return true
	var i := A.host(g, s)
	return i == null or i.controller_id != pid

static func _land(i: CardInstance) -> bool: return i.is_land()
static func _swamp(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("swamp")
static func _forest(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("forest")

## A victim's id/stamp (a creature) or seat (a player) for a DAMAGE_DEALT
## trigger, beside the usual source context.
static func _victim_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var hit: CardInstance = e.data.get("to_instance")
	if hit != null:
		out["victim"] = hit.id
		out["victim_stamp"] = hit.layer_timestamp
	else:
		out["victim_player"] = int(e.data.get("to_player", -1))
	return out

static func host_is_source(s: CardInstance, e: GameEvent) -> bool:
	var src: CardInstance = e.data.get("source")
	return src != null and s.attached_to != -1 and src.id == s.attached_to \
		and int(e.data.get("amount", 0)) > 0


# --------------------------------------------------------------------- Pariah --

static func _pariah(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null or not i.is_creature(): return
	g.add_static_damage_effect(s, {"kind": &"redirect", "victims": [{"player": s.controller_id}],
		"to": i, "desc": "Pariah: damage to %s is dealt to %s instead" % [
			g.players[s.controller_id].player_name, i.data.card_name]})


# -------------------------------------------------------------- Pendrell Flux --

## The granted trigger's source is the CREATURE; "you" is its controller as
## it triggered. "Its mana cost" is the creature's own (X = 0); no mana cost
## at all is unpayable (CR 118.6).
static func _flux_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	if s.controller_id != pid: return
	var cost := s.data.cost
	if cost != null and not cost.text.is_empty() and EffectBase.unless_paid(g, pid, s.data.cost_for(0),
			"Pay %s to keep %s?" % [cost.text, s.data.card_name]):
		return
	g.sacrifice_permanent(s)


# ----------------------------------------------------------- Zephid's Embrace --

static func _flying_and_shroud(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	if not i.cur_keywords.has(Mtg.Keyword.FLYING): i.cur_keywords.append(Mtg.Keyword.FLYING)
	i.cur_shroud = true


# ------------------------------------------------------------- Parasitic Bond --

## "That player": the enchanted creature's controller whose upkeep it is;
## the Aura deals the damage as it last existed if it has left (CR 608.2h).
static func _parasitic_bond(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	g.deal_damage(s, TargetRef.player(int(e.data.get("player", g.active_player))), 2)


# ----------------------------------------------------------- Vampiric Embrace --

static func _host_wounded_it(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	var dead: CardInstance = e.data.get("instance")
	if i == null or dead == null or dead == i or (dead.last_types & Mtg.CardType.CREATURE) == 0:
		return false
	return e.data.get("damage_origins", {}).has("%d:%d" % [i.id, i.layer_timestamp])

static func _vampiric_feed(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i != null: g.add_counters(i, "+1/+1")


# -------------------------------------------------------------------- Bravado --

## "You" is the AURA's controller; "other" is other than the enchanted
## creature (vis/_auras.gd, Vampirism).
static func _bravado(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	var others := 0
	for other in g.players[s.controller_id].battlefield:
		if other != i and other.is_creature() and not other.phased_out: others += 1
	i.cur_power += others
	i.cur_toughness += others


# ------------------------------------------- Blanchwood Armor / Granite Grip --

## "+P/+T for each <land type> you control" — the Aura's controller's lands
## of that LIVE subtype (layer 4 has settled before this layer-7c pump).
static func per_land(g: MtgGame, s: CardInstance, kind: String, power: int, toughness: int) -> void:
	var i := A.host(g, s)
	if i == null: return
	var n := 0
	for land in g.players[s.controller_id].battlefield:
		if land.is_land() and not land.phased_out and land.has_subtype(kind): n += 1
	i.cur_power += n * power
	i.cur_toughness += n * toughness


# ----------------------------------------------------------- Destructive Urge --

static func _host_hit_player_in_combat(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var packet: DamagePacket = e.data.get("packet")
	return host_is_source(s, e) and e.data.has("to_player") and packet != null and packet.is_combat

static func _destructive_urge(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).get("victim_player", -1))
	if who >= 0: sacrifice_one(g, who, _land, "a land")

## [param pid] sacrifices one permanent of their choice matching
## [param filter] (phased-out ones can't be, CR 702.26b).
static func sacrifice_one(g: MtgGame, pid: int, filter: Callable, desc: String) -> void:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if g.is_present(i) and filter.call(i): choices.append(i)
	if choices.is_empty(): return
	choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return Evaluator.permanent_value(a) < Evaluator.permanent_value(b))
	var picked := g.agents[pid].choose_card(g, pid, choices, "Select %s to sacrifice." % desc)
	if picked == null or not choices.has(picked): picked = choices[0]
	g.sacrifice_permanent(picked)


# ------------------------------------------------------------- Fertile Ground --

## "Its controller adds an additional one mana of any color" — the land's
## controller chooses. The answer the engine took before the tap was paid
## rides the event (`bonus_colors`, keyed by this Aura's id); a dispatch
## without one falls back to asking here, hinting the land's own colour
## (what the planner counted) or, for colorless mana, the colour the
## chooser's own hand asks for most (their own cards — fair).
static func _fertile_ground(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var pid := int(e.data.get("controller", -1))
	if pid < 0: return
	var color := int((e.data.get("bonus_colors", {}) as Dictionary).get(s.id, -1))
	if not Mtg.WUBRG.has(color):
		var hint := fertile_hint(g, pid, int(e.data.get("color", 0)))
		color = g.agents[pid].choose_color(g, pid, PlayerChoice.mana_color_prompt(s.data.card_name), hint)
		if not Mtg.WUBRG.has(color): color = hint
	g.players[pid].mana_pool.add(color, 1)
	g.log_line("Fertile Ground adds an additional %s mana" % String(Mtg.COLOR_NAMES[color]).to_lower())

static func fertile_hint(g: MtgGame, pid: int, made: int) -> int:
	if Mtg.WUBRG.has(made): return made
	var best := Mtg.ManaColor.G
	var most := 0
	for color in Mtg.WUBRG:
		var n := 0
		for card in g.players[pid].hand:
			if card.data.cost != null: n += int(card.data.cost.colored.get(color, 0))
		if n > most:
			most = n
			best = color
	return best


# ------------------------------------------------------------ Spreading Algae --

static func _algae(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i != null: g.destroy(i)


# ------------------------------------------------------------- Venomous Fangs --

static func _host_hit_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return host_is_source(s, e) and e.data.get("to_instance") != null

static func _venomous_fangs(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var victim := g.find_instance(int(ctx.get("victim", -1)))
	if g.is_present(victim) and victim.layer_timestamp == int(ctx.get("victim_stamp", -2)):
		g.destroy(victim)

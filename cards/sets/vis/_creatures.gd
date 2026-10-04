extends RefCounted
## Visions (_creatures, Pack 8). Creatures with activated, static or characteristic-defining abilities.
##
## Every listed name implements its whole Oracle text. Typed effects
## (PumpEffect, DestroyEffect, CounterMarkerEffect, RegenerateEffect,
## DamageAllEffect, SearchLibraryEffect...) wherever the shared vocabulary
## can say it, so the fair AI reads the ability (engine/ai/effect_intent.gd).
## Chronatog rides the E8 turn-structure API (MtgGame.skip_next_turn) and
## King Cheetah the E3 FLASH keyword.
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Daraja Griffin":
			c.activated(ActivatedAbility.new("", false, [DestroyEffect.new(TargetSpec.creature("target black creature", F._color.bind(Mtg.ManaColor.B)))],
				"Sacrifice this creature: Destroy target black creature.").with_sacrifice_cost())
		"Infantry Veteran":
			var pump := PumpEffect.new(1, 1)
			pump.target_spec = TargetSpec.creature("target attacking creature").with_game_filter(_attacking)
			c.activated(F._ability("", true, pump))
		"Jamuraan Lion":
			c.activated(F._ability("{W}", true, F.Action.new(_cant_block, "target creature can't block this turn", TargetSpec.creature())))
		"Resistance Fighter":
			c.activated(ActivatedAbility.new("", false, [PreventCombatDamageEffect.new().by_target_creature()],
				"Sacrifice this creature: Prevent all combat damage target creature would deal this turn.").with_sacrifice_cost())
		"Crypt Rats":
			# CR 107.3 + the printed "spend only black mana on X": the X is paid
			# in black pips (ActivatedAbility.with_colored_x, Drain Life's shape).
			c.activated(ActivatedAbility.new("{X}", false, [DamageAllEffect.new(0).x_damage().and_each_player()],
				"{X}: This creature deals X damage to each creature and each player. Spend only black mana on X.").with_colored_x(Mtg.ManaColor.B))
		"Necrosavant":
			c.activated(ActivatedAbility.new("{3}{B}{B}", false, [F.Action.new(_return_from_graveyard, "return this card from your graveyard to the battlefield", null, true)],
				"{3}{B}{B}, Sacrifice a creature: Return this card from your graveyard to the battlefield. Activate only during your upkeep.") \
				.from_graveyard().with_sacrifice_of("creature", B._creature).during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Urborg Mindsucker":
			var discard := RandomHandDiscardEffect.new(1)
			discard.target_spec = TargetSpec.opponent()
			c.activated(ActivatedAbility.new("{B}", false, [discard],
				"{B}, Sacrifice this creature: Target opponent discards a card at random. Activate only as a sorcery.").with_sacrifice_cost().only_if(_sorcery_speed))
		"Wake of Vultures":
			# "Sacrifice a creature" may eat this one too (Fallen Angel's reading);
			# the cost funnel offers the source last.
			c.activated(ActivatedAbility.new("{1}{B}", false, [RegenerateEffect.new()],
				"{1}{B}, Sacrifice a creature: Regenerate this creature.").with_sacrifice_of("creature", B._creature).may_sacrifice_itself())
		"Keeper of Kookus":
			c.activated(F._ability("{R}", false, F.Action.new(_protection_from_red, "this creature gains protection from red until end of turn", null, true)))
		"Spitting Drake":
			c.activated(F._ability("{R}", false, PumpEffect.new(1, 0).self_buff()).per_turn(1))
		"Giant Caterpillar":
			c.activated(ActivatedAbility.new("{G}", false, [DelayedButterfly.new()],
				"{G}, Sacrifice this creature: Create a 1/1 green Insect creature token with flying named Butterfly at the beginning of the next end step.").with_sacrifice_cost())
		"Kyscu Drake":
			c.activated(F._ability("{G}", false, PumpEffect.new(0, 1).self_buff()).per_turn(1))
			c.activated(ActivatedAbility.new("", false, [SearchLibraryEffect.new("a card named Viashivan Dragon", _named.bind("Viashivan Dragon")).to_battlefield()],
				"Sacrifice this creature and a creature named Spitting Drake: Search your library for a card named Viashivan Dragon, put that card onto the battlefield, then shuffle.") \
				.with_sacrifice_cost().with_sacrifice_of("creature named Spitting Drake", _named_creature.bind("Spitting Drake")))
		"Quirion Druid":
			# AI shape: Mishra's Groundbreaker's `permanent_animation` (one of its
			# own spare lands, policy in engine/ai/alliances_tactics.gd).
			c.activated(F._ability("{G}", true, F.Action.new(_awaken_land, "target land becomes a 2/2 green creature that's still a land",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", B._land), true).with_ai_role(&"permanent_animation")))
		"River Boa":
			c.activated(F._ability("{G}", false, RegenerateEffect.new()))
		"Army Ants":
			c.activated(ActivatedAbility.new("", true, [DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", B._land))],
				"{T}, Sacrifice a land: Destroy target land.").with_sacrifice_of("land", B._land))
		"Guiding Spirit":
			c.activated(F._ability("", true, F.Action.new(_guide, "if the top card of target player's graveyard is a creature card, put it on top of that player's library", TargetSpec.player())))
		"Mundungu":
			c.activated(F._ability("", true, LifeToll.new()))
		"Viashivan Dragon":
			c.activated(F._ability("{R}", false, PumpEffect.new(1, 0).self_buff()))
			c.activated(F._ability("{G}", false, PumpEffect.new(0, 1).self_buff()))
		"Brass-Talon Chimera", "Iron-Heart Chimera", "Lead-Belly Chimera", "Tin-Wing Chimera":
			var keyword := {"Brass-Talon Chimera": Mtg.Keyword.FIRST_STRIKE, "Iron-Heart Chimera": Mtg.Keyword.VIGILANCE,
				"Lead-Belly Chimera": Mtg.Keyword.TRAMPLE, "Tin-Wing Chimera": Mtg.Keyword.FLYING}[c.card_name] as int
			var word := {Mtg.Keyword.FIRST_STRIKE: "first strike", Mtg.Keyword.VIGILANCE: "vigilance",
				Mtg.Keyword.TRAMPLE: "trample", Mtg.Keyword.FLYING: "flying"}[keyword] as String
			c.activated(ActivatedAbility.new("", false, [ChimeraBoon.new(keyword, word)],
				"Sacrifice this creature: Put a +2/+2 counter on target Chimera creature. It gains %s. (This effect lasts indefinitely.)" % word).with_sacrifice_cost())
		"Chronatog":
			# The skip belongs to "you", the ability's controller, and happens even
			# if the Atog has left (only the pump needs its source, CR 608.2b).
			# The unknown second effect keeps the AI from reading this as a free
			# +3/+3 breath (EffectIntent.unknown): a turn is never worth it to it.
			c.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(3, 3).self_buff(), F.Action.new(_skip_turn, "you skip your next turn")],
				"{0}: This creature gets +3/+3 until end of turn. You skip your next turn. Activate only once each turn.").per_turn(1))
		"King Cheetah":
			c.with_keywords([Mtg.Keyword.FLASH])   # E3: cast any time you could cast an instant
		"Matopi Golem":
			c.activated(F._ability("{1}", false, ThisWayRegeneration.new("matopi")))
		"Phyrexian Marauder":
			c.as_it_enters(_marauder_counters)
			c.static_ability(StaticAbility.new(_marauder_rules, "This creature can't block. This creature can't attack unless you pay {1} for each +1/+1 counter on it."))
		_: return false
	return true


# --------------------------------------------------------------- helpers --

static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _anything(_i: CardInstance) -> bool: return true
static func _named(i: CardInstance, name: String) -> bool: return i.data.card_name == name
static func _named_creature(i: CardInstance, name: String) -> bool: return i.is_creature() and i.data.card_name == name

## "Activate only as a sorcery" (CR 307.1): your turn, a main phase, an
## empty stack — Illusionary Mask's test.
static func _sorcery_speed(g: MtgGame, s: CardInstance) -> String:
	if g.active_player != s.controller_id or not Mtg.is_main_step(g.current_step()) or not g.stack.is_empty():
		return "activate only as a sorcery"
	return ""

## Panic's floating "can't block this turn", bound to the creature: it is
## forgotten if that creature leaves (CR 400.7), and expires at cleanup.
static func _cant_block(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
	g.continuous.add_floating_static(s, StaticAbility.new(_no_block.bind(i.id), "Can't block this turn."), ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()

static func _no_block(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD: i.cur_cant_block_filter = _anything

## Graveyard activation (Ashen Ghoul's shape): only the card that paid the
## cost from this graveyard visit comes back (CR 400.7).
static func _return_from_graveyard(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.cost_paid("_source_graveyard_entry", -1)):
		g.reanimate(s, pid)

static func _skip_turn(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.skip_next_turn(pid)

static func _protection_from_red(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not B.live_source(g, s): return
	g.continuous.add_until_eot_protection(s.id, Mtg.ManaColor.R)
	g.recalculate()

## "Becomes a 2/2 green creature that's still a land" with no duration:
## indefinite (CR 611.2b). Layer 4 adds the type and 7b sets the base P/T
## (the animation registry), layer 5 sets the colour; forgotten if the land
## leaves (CR 400.7).
static func _awaken_land(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var land := g.find_instance(t.instance_id)
	if land == null or land.zone != Mtg.Zone.BATTLEFIELD: return
	g.continuous.add_until_eot_animation(land.id, Mtg.CardType.CREATURE, 2, 2, [], false, ContinuousEffects.Duration.INDEFINITE)
	g.continuous.add_until_eot_color(land.id, Mtg.ManaColor.G, false, ContinuousEffects.Duration.INDEFINITE)
	g.recalculate()

static func _guide(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var grave := g.players[t.player_id].graveyard
	if grave.is_empty(): return
	var top: CardInstance = grave.back()
	if top.is_creature(): g.return_from_graveyard_to_library_top(top)

static func _marauder_counters(g: MtgGame, s: CardInstance, _pid: int) -> void:
	var x := int(s.memory.get("x_value", 0))
	if x > 0: g.add_counters(s, "+1/+1", x)

## Can't block, and an ATTACK COST of {1} per +1/+1 counter read live as
## attackers are declared (CR 508.1g; Brainwash's cur_attack_costs).
static func _marauder_rules(_g: MtgGame, s: CardInstance) -> void:
	s.cur_cant_block_filter = _anything
	var n := int(s.counters.get("+1/+1", 0))
	if n > 0:
		s.cur_attack_costs.append({"desc": "you pay {%d}" % n, "generic_mana": n,
			"can_pay": _can_pay_generic.bind(n), "pay": _paid_by_engine})

static func _can_pay_generic(g: MtgGame, pid: int, n: int) -> bool: return g.can_afford_cost(pid, ManaCost.parse("{%d}" % n))
static func _paid_by_engine(_g: MtgGame, _pid: int) -> void: pass


# --------------------------------------------------------------- effects --

## "Counter target spell unless its controller pays {1} and 1 life." Both
## halves are one payment: a player who cannot pay both pays neither
## (CR 118.12, 119.4 — life can be paid only from a total at least that big).
class LifeToll extends CounterEffect:
	func _init() -> void:
		super("target spell")
	func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef, _x := 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK: return
		var item := game.find_stack_item(spell)
		var pid := spell.controller_id if item == null else item.controller
		var mana := ManaCost.parse("{1}")
		if game.players[pid].life >= 1 and game.can_afford_cost(pid, mana) \
				and game.agents[pid].choose_yes_no(game, pid, "Pay {1} and 1 life to prevent the counter?", true) \
				and game.try_pay(pid, mana):
			game.adjust_life(pid, -1)
			return
		game.counter_spell(spell)
	func describe() -> String:
		return "counter target spell unless its controller pays {1} and 1 life"

## The Chimera cycle's payload: a +2/+2 counter AND a keyword with no
## duration (CR 611.2b: it lasts as long as the creature stays). One effect,
## so the ability has ONE target; read by the AI as a counter pump.
class ChimeraBoon extends CounterMarkerEffect:
	var keyword: int
	var word: String
	func _init(granted: int, keyword_word: String) -> void:
		super("+2/+2", 1, TargetSpec.creature("target Chimera creature", F._subtype.bind("chimera")))
		keyword = granted
		word = keyword_word
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x := 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD: return
		super(game, source, controller, target, x)
		game.grant_keyword_permanently(inst, keyword)
	func describe() -> String:
		return "put a +2/+2 counter on target Chimera creature; it gains " + word

## "...at the beginning of the next end step" is a DELAYED triggered ability
## (CR 603.7): it goes on the stack at that end step and survives the
## sacrificed source. Read by the AI as the token it makes.
class DelayedButterfly extends CreateTokenEffect:
	func _init() -> void:
		super("Butterfly", 1, 1, Mtg.ManaColor.G, "insect")
		token.with_keywords([Mtg.Keyword.FLYING]).oracle("Flying")
	func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef, _x := 0) -> void:
		game.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _make.bind(token, controller),
			"Create a 1/1 green Insect creature token with flying named Butterfly."), controller, source)
	static func _make(game: MtgGame, _s: CardInstance, _e: GameEvent, data: CardData, who: int) -> void:
		game.create_token(who, data)
	func describe() -> String:
		return "create a 1/1 green Insect creature token with flying named Butterfly at the beginning of the next end step"

## "Regenerate <it>. <Something> if/when it regenerates THIS WAY" — Matopi
## Golem's -1/-1 counter (a delayed trigger, CR 603.7) and Debt of Loyalty's
## control change. The shield is the engine's ordinary one; the "this way"
## half is a delayed entry per shield, keyed to the creature's object
## (id + timestamp, CR 400.7) and expiring with the shield at cleanup
## (CR 701.15). One regeneration answers one entry, the oldest.
## SIMPLIFIED (docs/simplified-cards.md, "Matopi Golem"; "Debt of Loyalty"):
## shields are interchangeable counts in the engine and CR 616.1's choice
## among them is not asked — every "this way" rider is a price to the
## creature's controller (a counter, a lost creature), so any OTHER shield
## is taken as spent first: the rider applies only when the shields left
## after this regeneration are fewer than this kind's pending entries.
class ThisWayRegeneration extends RegenerateEffect:
	var kind: String
	func _init(rider: String, spec: TargetSpec = null) -> void:
		super()
		kind = rider
		if spec != null: target_spec = spec
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x := 0) -> void:
		var affected := source if target_spec == null else game.find_instance(target.instance_id)
		if affected == null or affected.zone != Mtg.Zone.BATTLEFIELD: return
		if target_spec == null and not B.live_source(game, source): return
		var before := affected.regeneration_shields
		super(game, source, controller, target, x)
		if affected.regeneration_shields <= before: return
		var seq := game.continuous.next_timestamp()
		var memory := {"regenerated_this_way": kind, "id": affected.id, "stamp": affected.layer_timestamp, "seq": seq}
		var condition := ThisWayRegeneration._this_way.bind(kind, affected.id, affected.layer_timestamp, seq)
		var trigger: TriggeredAbility
		if kind == "debt":
			# Debt of Loyalty: the control change is part of the regeneration
			# itself, not a trigger anyone can answer — it rides the engine's
			# off-stack delayed path (the one High Tide's mana uses).
			trigger = TriggeredAbility.new(Mtg.EventType.REGENERATED, ThisWayRegeneration._gain_control.bind(controller, affected.id, affected.layer_timestamp),
				"You gain control of that creature.", condition).as_mana_trigger()
		else:
			trigger = TriggeredAbility.new(Mtg.EventType.REGENERATED, ThisWayRegeneration._shrink.bind(affected.id, affected.layer_timestamp),
				"When it regenerates this way, put a -1/-1 counter on it.", condition)
		var entry := game.schedule_delayed_trigger(trigger, controller, source, false, memory)
		entry["expires_turn"] = game.turn_number
	static func _this_way(g: MtgGame, _s: CardInstance, e: GameEvent, rider: String, id: int, stamp: int, seq: int) -> bool:
		var inst: CardInstance = e.data.get("instance")
		if inst == null or inst.id != id or inst.layer_timestamp != stamp: return false
		var pending := 0
		var first := seq
		for entry in g.delayed_triggers:
			var memory: Dictionary = entry.get("memory", {})
			if String(memory.get("regenerated_this_way", "")) == rider and int(memory.get("id", -1)) == id \
					and int(memory.get("stamp", -1)) == stamp:
				pending += 1
				first = mini(first, int(memory.get("seq", seq)))
		return first == seq and inst.regeneration_shields < pending
	static func _shrink(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
		var inst := g.find_instance(id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.layer_timestamp == stamp: g.add_counters(inst, "-1/-1")
	static func _gain_control(g: MtgGame, _s: CardInstance, _e: GameEvent, who: int, id: int, stamp: int) -> void:
		var inst := g.find_instance(id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.layer_timestamp == stamp and inst.controller_id != who:
			g.change_control(inst, who)
	func describe() -> String:
		if kind == "debt": return "regenerate target creature; you gain control of it if it regenerates this way"
		return "regenerate this creature; when it regenerates this way, put a -1/-1 counter on it"

extends RefCounted
## Mirage (_artifacts, Pack 8). Noncreature artifacts and their activated or static abilities.
##
## Acidic Dagger — two DELAYED triggers created by the ability (CR 603.7),
##   both expiring with the turn ("expires_turn"): every time the targeted
##   creature deals COMBAT damage to a non-Wall creature that creature is
##   destroyed (regeneration allowed), and when the targeted creature leaves
##   the battlefield the Dagger's controller sacrifices the Dagger (the same
##   object only, CR 400.7). "Activate only before blockers are declared" is
##   ActivatedAbility.before_step(DECLARE_BLOCKERS).
## Amber Prison — Ice Floe's freeze: a floating static bound to the tapped
##   permanent that holds only while the Prison stays tapped since that
##   activation (its untap sequence), plus "you may choose not to untap".
## Bone Mask — SourceShieldEffect.prevent_to_you() (E5) with a rider that
##   exiles that many cards from the top of the controller's library, face up.
## Chariot of the Sun — a flying pump plus a layer-7b toughness-only base
##   set (ContinuousEffects.add_until_eot_base_pt with power -1).
## Cursed Totem — CardData.bans_activations (E4): creatures' abilities,
##   mana abilities included (CR 605.1a).
## Grinning Totem — the searcher picks from the opponent's library (a search
##   shows them the cards), the card is exiled face up and playable by the
##   searcher until their next upkeep (MtgGame.grant_exile_play), and a
##   delayed upkeep trigger puts it into its owner's graveyard if it is still
##   that exiled object (CR 400.7: played = gone).
## Mangara's Tome — the pile is exiled face down (nobody may look), its order
##   shuffled with the game's RNG and kept on the Tome; the {2} ability reads
##   the pile as it was when it was activated (recorded with the cost — the
##   linked ability still knows its pile if the Tome leaves, CR 607.2a) and
##   registers a one-shot draw replacement for this turn (MtgGame.
##   replace_next_draw). An empty pile still replaces the draw: nothing is
##   put into the hand and nothing is drawn.
## The cages / Razor Pendulum — intervening-if upkeep / end step triggers
##   (CR 603.4: checked as they trigger and again as they resolve).
## Unerring Sling — "Tap an untapped creature you control" is an object cost
##   (E6, OC.tapping); the damage is that creature's power as the ability
##   resolves (its last known power if it has left, CR 608.2h).
## Ventifact Bottle — MAIN_PHASE_START (E8), precombat only, intervening if;
##   the mana is added by the resolving trigger (it is not a mana ability).
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Acidic Dagger":
			c.activated(ActivatedAbility.new("{4}", true, [Dagger.new()],
				"{4}, {T}: Whenever target creature deals combat damage to a non-Wall creature this turn, destroy that non-Wall creature. When the targeted creature leaves the battlefield this turn, sacrifice this artifact. Activate only before blockers are declared.") \
				.before_step(Mtg.Step.DECLARE_BLOCKERS))
		"Amber Prison":
			c.with_may_skip_untap()
			c.activated(ActivatedAbility.new("{4}", true,
				[Freeze.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", acl))],
				"{4}, {T}: Tap target artifact, creature, or land. That permanent doesn't untap during its controller's untap step for as long as this artifact remains tapped."))
		"Amulet of Unmaking":
			c.activated(ActivatedAbility.new("{5}", true,
				[ExileEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", acl))],
				"{5}, {T}, Exile this artifact: Exile target artifact, creature, or land. Activate only as a sorcery.") \
				.with_exile_cost().only_if(sorcery_speed))
		"Bone Mask":
			c.activated(ActivatedAbility.new("{2}", true, [SourceShieldEffect.prevent_to_you().with_rider(_bone_rider)],
				"{2}, {T}: The next time a source of your choice would deal damage to you this turn, prevent that damage. Exile cards from the top of your library equal to the damage prevented this way."))
		"Chariot of the Sun":
			c.activated(ActivatedAbility.new("{2}", true, [Chariot.new()],
				"{2}, {T}: Until end of turn, target creature you control gains flying and has base toughness 1."))
		"Cursed Totem":
			c.bans_activations(_cursed_totem)
		"Elixir of Vitality":
			c.with_enters_tapped()
			c.activated(ActivatedAbility.new("", true, [GainLifeEffect.new(4)],
				"{T}, Sacrifice this artifact: You gain 4 life.").with_sacrifice_cost())
			c.activated(ActivatedAbility.new("{8}", true, [GainLifeEffect.new(8)],
				"{8}, {T}, Sacrifice this artifact: You gain 8 life.").with_sacrifice_cost())
		"Grinning Totem":
			c.activated(ActivatedAbility.new("{2}", true, [Grin.new()],
				"{2}, {T}, Sacrifice this artifact: Search target opponent's library for a card and exile it. Then that player shuffles. Until the beginning of your next upkeep, you may play that card. At the beginning of your next upkeep, if you haven't played it, put it into its owner's graveyard.") \
				.with_sacrifice_cost())
		"Mangara's Tome":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _tome_enter,
				"When this artifact enters, search your library for five cards, exile them in a face-down pile, and shuffle that pile. Then shuffle your library.",
				F._self_enter))
			var tome := ActivatedAbility.new("{2}", false, [TomeDraw.new()],
				"{2}: The next time you would draw a card this turn, instead put the top card of the exiled pile into its owner's hand.")
			tome.on_cost_paid = _tome_paid
			c.activated(tome)
		"Misers' Cage":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _cage_bite,
				"At the beginning of each opponent's upkeep, if that player has five or more cards in hand, this artifact deals 2 damage to that player.",
				_misers_upkeep))
		"Paupers' Cage":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _cage_bite,
				"At the beginning of each opponent's upkeep, if that player has two or fewer cards in hand, this artifact deals 2 damage to that player.",
				_paupers_upkeep))
		"Phyrexian Vault":
			c.activated(ActivatedAbility.new("{2}", true, [DrawEffect.new(1)],
				"{2}, {T}, Sacrifice a creature: Draw a card.").with_sacrifice_of("creature", _creature))
		"Razor Pendulum":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _pendulum,
				"At the beginning of each player's end step, if that player has 5 or less life, this artifact deals 2 damage to that player.",
				_pendulum_due))
		"Telim'Tor's Darts":
			c.activated(ActivatedAbility.new("{2}", true, [DamageEffect.new(1).target_player()],
				"{2}, {T}: This artifact deals 1 damage to target player or planeswalker."))
		"Unerring Sling":
			c.activated(ActivatedAbility.new("{3}", true, [Sling.new()],
				"{3}, {T}, Tap an untapped creature you control: This artifact deals damage equal to the tapped creature's power to target attacking or blocking creature with flying.") \
				.with_object_cost(OC.tapping("an untapped creature you control", _creature)))
		"Ventifact Bottle":
			c.activated(ActivatedAbility.new("{X}{1}", true, [Charge.new()],
				"{X}{1}, {T}: Put X charge counters on this artifact. Activate only as a sorcery.").only_if(sorcery_speed))
			c.triggered(TriggeredAbility.new(Mtg.EventType.MAIN_PHASE_START, _bottle_drain,
				"At the beginning of your first main phase, if this artifact has a charge counter on it, tap it and remove all charge counters from it. Add {C} for each charge counter removed this way.",
				_bottle_due))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

static func acl(i: CardInstance) -> bool:
	return i.is_creature() or i.is_land() or i.is_type(Mtg.CardType.ARTIFACT)
static func _creature(i: CardInstance) -> bool: return i.is_creature()

## "Activate only as a sorcery" (CR 307.1): your turn, a main phase, an
## empty stack — Illusionary Mask's test.
static func sorcery_speed(g: MtgGame, s: CardInstance) -> String:
	if g.active_player != s.controller_id or not Mtg.is_main_step(g.current_step()) or not g.stack.is_empty():
		return "activate only as a sorcery"
	return ""

## The resolving ability's source is still the object that activated it.
static func same_activation(g: MtgGame, s: CardInstance) -> bool:
	return g.is_present(s) and s.layer_timestamp == int(g.cost_paid("_source_timestamp", s.layer_timestamp))

## "You" for a resolving trigger or ability.
static func pid_of(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id


# -------------------------------------------------------------- Acidic Dagger --

class Dagger extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		ai_helpful = true
	func resolve(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var bearer := g.find_instance(t.instance_id)
		if not g.is_present(bearer): return
		var module: GDScript = load("res://cards/sets/mir/_artifacts.gd")
		var hit := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, module._dagger_destroy,
			"Whenever that creature deals combat damage to a non-Wall creature this turn, destroy that non-Wall creature.",
			module._dagger_hit.bind(bearer.id, bearer.layer_timestamp, g.turn_number)), pid, source, true)
		hit["expires_turn"] = g.turn_number
		var gone := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD,
			module._dagger_sacrifice.bind(int(g.cost_paid("_source_timestamp", source.layer_timestamp)), pid),
			"When the targeted creature leaves the battlefield this turn, sacrifice this artifact.",
			module._dagger_gone.bind(bearer.id, bearer.layer_timestamp, g.turn_number)), pid, source)
		gone["expires_turn"] = g.turn_number
	func describe() -> String:
		return "target creature's combat damage destroys the non-Wall creatures it hits this turn"

static func _dagger_hit(g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int, turn: int) -> bool:
	var dealer: CardInstance = e.data.get("source")
	var victim: CardInstance = e.data.get("to_instance")
	var packet: DamagePacket = e.data.get("packet")
	return g.turn_number == turn and dealer != null and dealer.id == id and dealer.layer_timestamp == stamp \
		and packet != null and packet.is_combat and int(e.data.get("amount", 0)) > 0 \
		and victim != null and victim.is_creature() and not victim.has_subtype("wall")

static func _dagger_destroy(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var victim: CardInstance = e.data.get("to_instance")
	if g.is_present(victim) and not victim.has_subtype("wall"): g.destroy(victim)

static func _dagger_gone(g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int, turn: int) -> bool:
	var left: CardInstance = e.data.get("instance")
	return g.turn_number == turn and left != null and left.id == id and left.layer_timestamp == stamp

static func _dagger_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent, stamp: int, pid: int) -> void:
	if g.is_present(s) and s.layer_timestamp == stamp and s.controller_id == pid:
		g.sacrifice_permanent(s)


# --------------------------------------------------------------- Amber Prison --

class Freeze extends TapEffect:
	func _init(spec: TargetSpec) -> void:
		super(spec)
		with_ai_role(&"sustained_lock")   # the AI's reading of Ice Floe / Whip Vine
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var stamp := int(g.cost_paid("_source_timestamp", s.layer_timestamp))
		var untaps := int(g.cost_paid("_source_untap_sequence", s.untap_sequence))
		if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped or s.untap_sequence != untaps: return
		var target := g.find_instance(t.instance_id)
		if not g.is_present(target): return
		# What the untap step's "you may choose not to untap" heuristic reads
		# (MtgGame._is_sustaining): this Prison holds something.
		g._rec(s, &"memory")
		s.memory["holding"] = target.id
		g.continuous.add_floating_static(s, StaticAbility.new(
			(load("res://cards/sets/mir/_artifacts.gd") as GDScript)._freeze.bind(target.id, target.layer_timestamp, stamp, untaps),
			"Doesn't untap during its controller's untap step for as long as Amber Prison remains tapped."),
			ContinuousEffects.Duration.INDEFINITE, -1, false, target.id)
		g.recalculate()
	func describe() -> String:
		return "tap %s; it doesn't untap for as long as this artifact remains tapped" % target_spec.description

static func _freeze(g: MtgGame, s: CardInstance, id: int, target_stamp: int, stamp: int, untaps: int) -> void:
	if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped or s.untap_sequence != untaps: return
	var i := g.find_instance(id)
	if g.is_present(i) and i.layer_timestamp == target_stamp: i.cur_skips_untap = true


# ------------------------------------------------------------------ Bone Mask --

static func _bone_rider(g: MtgGame, _packet: DamagePacket, amount: int, _src: CardInstance, pid: int) -> void:
	for _n in amount:
		if g.exile_top_of_library(pid, false) == null: break


# --------------------------------------------------------- Chariot of the Sun --

class Chariot extends PumpEffect:
	func _init() -> void:
		super(0, 0, [Mtg.Keyword.FLYING])
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(_yours).because("controller")
	static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s != null and i.controller_id == g.controller_acting_for(s)
	func resolve(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		super(g, source, pid, t, x)
		g.continuous.add_until_eot_base_pt(i.id, -1, 1)   # toughness only, layer 7b
		g.recalculate()
	func describe() -> String:
		return "until end of turn, target creature you control gains flying and has base toughness 1"


# --------------------------------------------------------------- Cursed Totem --

static func _cursed_totem(_g: MtgGame, _s: CardInstance, _pid: int, inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return inst.is_creature()


# ------------------------------------------------------------- Grinning Totem --

class Grin extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var candidates: Array[CardInstance] = g.players[who].library.duplicate()
		if candidates.is_empty():
			g.shuffle_library(who)
			return
		# Best-first for the searcher, who sees the library while searching:
		# spells before lands, the costliest first.
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if a.data.is_land() != b.data.is_land(): return b.data.is_land()
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := g.agents[pid].choose_card(g, pid, candidates,
			"%s: choose a card to exile" % source.data.card_name, false, false, true)
		if pick == null or not candidates.has(pick): pick = candidates[0]
		g.exile_library_card(pick)
		g.shuffle_library(who)
		if pick.zone != Mtg.Zone.EXILE: return
		g.grant_exile_play(pick, pid, true)
		var module: GDScript = load("res://cards/sets/mir/_artifacts.gd")
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, module._grin_expire,
			"At the beginning of your next upkeep, if you haven't played it, put it into its owner's graveyard.",
			module._upkeep_of.bind(pid)), pid, source, false, {"card": pick.id, "entry": pick.exile_entry})
	func describe() -> String:
		return "exile a card from target opponent's library; you may play it until your next upkeep"

static func _upkeep_of(_g: MtgGame, _s: CardInstance, e: GameEvent, pid: int) -> bool:
	return int(e.data.get("player", -1)) == pid

static func _grin_expire(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var card := g.find_instance(int(memory.get("card", -1)))
	if card != null and card.zone == Mtg.Zone.EXILE and card.exile_entry == int(memory.get("entry", -1)):
		g.return_from_exile_to_graveyard(card)


# -------------------------------------------------------------- Mangara's Tome --

static func _tome_enter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	var pile: Array = []
	for n in 5:
		var candidates: Array[CardInstance] = g.players[pid].library.duplicate()
		if candidates.is_empty(): break
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if a.data.is_land() != b.data.is_land(): return b.data.is_land()
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := g.agents[pid].choose_card(g, pid, candidates,
			"%s: choose a card for the exiled pile (%d/5)" % [s.data.card_name, n + 1], false, false, true)
		if pick == null or not candidates.has(pick): pick = candidates[0]
		g.move_library_card_to_top(pick)
		var exiled := g.exile_top_of_library(pid, true, -1)
		if exiled != null: pile.append([exiled.id, exiled.exile_entry])
	# "Shuffle that pile": its order is the game's RNG's, unknown to all.
	for n in range(pile.size() - 1, 0, -1):
		var k := g.rng.randi_range(0, n)
		var swap = pile[n]
		pile[n] = pile[k]
		pile[k] = swap
	g.shuffle_library(pid)
	if F._same_trigger_source(g, s):
		g._rec(s, &"memory")
		s.memory["pile"] = pile

static func _tome_paid(_g: MtgGame, source: CardInstance, paid: Dictionary) -> void:
	paid["_tome_pile"] = (source.memory.get("pile", []) as Array).duplicate(true)

class TomeDraw extends EffectBase:
	func _init() -> void:
		ai_helpful = true
	func resolve(g: MtgGame, source: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var pile: Array = g.cost_paid("_tome_pile", [])
		var module: GDScript = load("res://cards/sets/mir/_artifacts.gd")
		g.replace_next_draw(pid, module._tome_instead.bind(pile.duplicate(true)),
			"%s: put the top card of the exiled pile into its owner's hand" % source.data.card_name)
	func describe() -> String:
		return "the next time you would draw a card this turn, instead put the top card of the exiled pile into its owner's hand"

static func _tome_instead(g: MtgGame, _pid: int, _ctx: Dictionary, pile: Array) -> void:
	for row in pile:
		var card := g.find_instance(int(row[0]))
		if card != null and card.zone == Mtg.Zone.EXILE and card.exile_entry == int(row[1]):
			g.return_from_exile_to_hand(card, false)
			return


# ---------------------------------------------------------------- the cages --

static func _misers_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("player", -1))
	return who >= 0 and who != s.controller_id and g.players[who].hand.size() >= 5

static func _paupers_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("player", -1))
	return who >= 0 and who != s.controller_id and g.players[who].hand.size() <= 2

## The intervening "if" is asked again on resolution (CR 603.4).
static func _cage_bite(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	var hand := g.players[who].hand.size()
	var holds := hand >= 5 if s.data.card_name == "Misers' Cage" else hand <= 2
	if holds: g.deal_damage(s, TargetRef.player(who), 2)


# ------------------------------------------------------------ Razor Pendulum --

static func _pendulum_due(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("player", -1))
	return who >= 0 and g.players[who].life <= 5

static func _pendulum(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if g.players[who].life <= 5: g.deal_damage(s, TargetRef.player(who), 2)


# ------------------------------------------------------------- Unerring Sling --

class Sling extends DamageEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.creature("target attacking or blocking creature with flying", _flier) \
			.with_game_filter(_in_combat).because("attacking_blocking")
	static func _flier(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
	static func _in_combat(g: MtgGame, i: CardInstance) -> bool:
		return g.combat.attackers.has(i.id) or not g.combat.attackers_blocked_by(i.id).is_empty()
	func resolve(g: MtgGame, source: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var rows: Array = g.cost_paid("_object_costs", [])
		if rows.is_empty(): return
		var row: Dictionary = rows[0]
		var body := g.find_instance(int(row.get("id", -1)))
		var power := int(row.get("power", 0))
		if g.is_present(body) and body.layer_timestamp == int(row.get("stamp", -2)):
			power = body.cur_power
		if power > 0: g.deal_damage(source, t, power)
	func describe() -> String:
		return "deals damage equal to the tapped creature's power to target attacking or blocking creature with flying"


# ----------------------------------------------------------- Ventifact Bottle --

class Charge extends EffectBase:
	func _init() -> void:
		ai_helpful = true
	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, x := 0) -> void:
		if x > 0 and g.is_present(source) and source.layer_timestamp == int(g.cost_paid("_source_timestamp", source.layer_timestamp)):
			g.add_counters(source, "charge", x)
	func describe() -> String:
		return "put X charge counters on this artifact"

static func _bottle_due(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return bool(e.data.get("precombat", false)) and int(e.data.get("player", -1)) == s.controller_id \
		and int(s.counters.get("charge", 0)) > 0

static func _bottle_drain(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._trigger_source_present(g, s): return
	var n := int(s.counters.get("charge", 0))
	if n <= 0: return   # CR 603.4: the "if" is false now
	g.tap_permanent(s)
	g.remove_counters(s, "charge", n)
	AddManaEffect.new(Mtg.ManaColor.C, n).resolve(g, s, pid_of(g, s), null)

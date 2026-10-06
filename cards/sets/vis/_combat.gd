extends RefCounted
## Visions (_combat, Pack 8). Combat rules: flanking, blocking and attacking restrictions, combat triggers.
##
## Same conventions as the Mirage module (cards/sets/mir/_combat.gd), whose
## shared helpers ([code]MC.flanking[/code], the BLOCKED pair triggers, the
## per-creature attack fan-out, "assigns no combat damage") this one uses.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Knight of Valor":
			MC.flanking(c)
			c.activated(ActivatedAbility.new("{1}{W}", false,
				[F.Action.new(_valor, "each creature without flanking blocking this creature gets -1/-1 until end of turn", null, true)],
				"{1}{W}: Each creature without flanking blocking this creature gets -1/-1 until end of turn. Activate only once each turn.").per_turn(1))
		"Zhalfirin Crusader":
			MC.flanking(c)
			c.activated(ActivatedAbility.new("{1}{W}", false, [CrusaderRedirect.new()],
				"{1}{W}: The next 1 damage that would be dealt to this creature this turn is dealt to any target instead."))
		# ------------------------------------------------------------- blue
		"Cloud Elemental":
			c.static_ability(StaticAbility.new(_cloud, "This creature can block only creatures with flying."))
		"Knight of the Mists":
			MC.flanking(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _mists,
				"When this creature enters, you may pay {U}. If you don't, destroy target Knight and it can't be regenerated.",
				F._self_enter).targeting(TargetSpec.creature("target Knight", MC.P.knight), _knight_order,
				"Select a Knight."))
		# ------------------------------------------------------------ black
		"Fallen Askari":
			MC.flanking(c)
			c.static_ability(StaticAbility.new(_no_block, "This creature can't block."))
		"Suq'Ata Assassin":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, MC.poison_defender,
				"Whenever this creature attacks and isn't blocked, defending player gets a poison counter.",
				F._self_enter))
		# -------------------------------------------------------------- red
		"Dwarven Vigilantes":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _vigilantes,
				"Whenever this creature attacks and isn't blocked, you may have it deal damage equal to its power to target creature. If you do, this creature assigns no combat damage this turn.",
				F._self_enter).targeting(TargetSpec.creature(), F._enemy_first,
				"Select a creature for Dwarven Vigilantes to damage."))
		"Goblin Swine-Rider":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, _swine_rider,
				"Whenever this creature becomes blocked, it deals 2 damage to each attacking creature and each blocking creature.",
				F._self_enter))
		"Heat Wave":
			CumulativeUpkeep.attach(c, "{R}")
			c.static_ability(StaticAbility.new(_heat_wave,
				"Blue creatures can't block creatures you control. Nonblue creatures can't block creatures you control unless their controller pays 1 life for each blocking creature they control."))
		"Raging Gorilla":
			MC.self_combat_pump(c, 2, -2, "Whenever this creature blocks or becomes blocked, it gets +2/-2 until end of turn.")
		"Rock Slide":
			var slide := DamageEffect.new(0)
			slide.target_spec = TargetSpec.creature("target attacking or blocking creature without flying",
				MC.P.without_flying).with_game_filter(_in_combat).because("attacking/blocking")
			c.spell(slide.divided(-1))
		"Song of Blood": c.spell(SongOfBlood.new())
		"Suq'Ata Lancer": MC.flanking(c)
		"Talruum Champion":
			c.triggered(MC.pair_trigger(MC.EITHER, Callable(), _champion,
				"Whenever this creature blocks or becomes blocked by a creature, that creature loses first strike until end of turn."))
		"Talruum Piper":
			c.static_ability(StaticAbility.new(_piper, "All creatures with flying able to block this creature do so."))
		# ------------------------------------------------------------ green
		"Elephant Grass":
			CumulativeUpkeep.attach(c, "{1}")
			c.static_ability(StaticAbility.new(_elephant_grass,
				"Black creatures can't attack you. Nonblack creatures can't attack you unless their controller pays {2} for each creature they control that's attacking you."))
		"Wind Shear": c.spell(WindShear.new())
		# ------------------------------------------------------------- gold
		"Pygmy Hippo":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _hippo,
				"Whenever this creature attacks and isn't blocked, you may have defending player activate a mana ability of each land they control and lose all unspent mana. If you do, this creature assigns no combat damage this turn and at the beginning of your next main phase this turn, you add an amount of {C} equal to the amount of mana that player lost this way.",
				F._self_enter))
		_: return false
	return true


# ================================================================== white

## Knight of Valor: "blocking this creature" — a creature blocking any
## member of its band blocks it too (CR 702.22h); "without flanking" is
## read as the ability resolves.
static func _valor(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not MC.live_source(g, s): return
	for id in g.combat.blockers_of_band(g.combat.band_of(s.id)):
		var b := g.find_instance(int(id))
		if g.is_present(b) and not b.has_keyword(Mtg.Keyword.FLANKING):
			g.continuous.add_until_eot_pump(b.id, -1, -1)
	g.recalculate()


## Zhalfirin Crusader: a metered redirection (Pack 8 E5,
## MtgGame.redirect_next_damage_points) — one point of the next damage to
## this creature this turn goes to the target chosen on activation.
class CrusaderRedirect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()
		is_damage_prevention = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not MC.live_source(g, s): return
		g.redirect_next_damage_points(pid, "Zhalfirin Crusader", s, 1, t)
	func describe() -> String:
		return "the next 1 damage that would be dealt to this creature this turn is dealt to %s instead" % target_spec.description


# =================================================================== blue

static func _cloud(_g: MtgGame, s: CardInstance) -> void:
	MC.cant_block(s, MC.P.without_flying)


## Knight of the Mists: the pay-or-destroy is the controller's choice as
## the trigger resolves (CR 118.12); the hint pays only to spare a Knight
## of their own.
static func _mists(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var victim := g.find_instance(targets[0].instance_id)
	if not g.is_present(victim): return
	var pid := MC.pid_of(g, s)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{U}"),
			"Pay {U}? If you don't, %s is destroyed and can't be regenerated." % victim.data.card_name,
			victim.controller_id == pid):
		return
	g.destroy(victim, false)


## The opponent's Knights first, the biggest first; then this seat's own,
## the smallest first (the trigger must target something — CR 603.3d).
static func _knight_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var me := g.controller_acting_for(s)
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	var a_enemy := ai.controller_id != me
	var b_enemy := bi.controller_id != me
	if a_enemy != b_enemy: return a_enemy
	var av := ai.cur_power + ai.cur_toughness
	var bv := bi.cur_power + bi.cur_toughness
	return av > bv if a_enemy else av < bv


# ================================================================== black

static func _no_block(_g: MtgGame, s: CardInstance) -> void:
	MC.cant_block(s, _anything)


static func _anything(_i: CardInstance) -> bool:
	return true


# ==================================================================== red

## Dwarven Vigilantes (Gaze of Pain's shape, cards/sets/ice/_declarations.gd):
## a creature that has left still deals the damage with its last known
## power (CR 608.2h), but only the object still here assigns no combat
## damage.
static func _vigilantes(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var victim := g.find_instance(targets[0].instance_id)
	if not g.is_present(victim): return
	var live := MC.same(g, s)
	var power := maxi(0, s.cur_power if live else s.last_power)
	var pid := MC.pid_of(g, s)
	var hint := victim.controller_id != pid and power > 0 \
		and power >= victim.cur_toughness - victim.damage
	if not g.agents[pid].choose_yes_no(g, pid,
			"Have Dwarven Vigilantes deal %d damage to %s instead of assigning combat damage?" % [power, victim.data.card_name], hint):
		return
	g.deal_damage(s, targets[0], power)
	if live and g.is_present(s):
		MC.assigns_no_combat_damage(g, s)


## Goblin Swine-Rider: every attacking and every blocking creature as the
## ability resolves, all at once — itself among them while it attacks.
static func _swine_rider(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var hit: Array[CardInstance] = []
	for id in g.combat.attackers:
		var i := g.find_instance(int(id))
		if g.is_present(i) and i.is_creature() and not hit.has(i): hit.append(i)
	for id in g.combat.blocks:
		var i := g.find_instance(int(id))
		if g.is_present(i) and i.is_creature() and not hit.has(i): hit.append(i)
	if hit.is_empty(): return
	g.begin_simultaneous()
	for i in hit:
		g.deal_damage(s, TargetRef.card(i), 2)
	g.end_simultaneous()


## Heat Wave (Pack 8 E9): the blue ban and the life tax, on every creature
## its controller controls.
static func _heat_wave(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if not i.is_creature(): continue
		i.cur_block_restrictions.append({"desc": "nonblue creatures", "filter": _nonblue})
		CombatState.add_block_life_tax(i, s, 1, _nonblue, "pay 1 life")


static func _nonblue(blocker: CardInstance) -> bool:
	return (blocker.cur_colors & Mtg.ManaColor.U) == 0


static func _in_combat(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id) or g.combat.blocks.has(i.id)


## Song of Blood: the creature CARDS this mill put into the graveyard
## (a card exiled instead — Forbidden Crypt — was not), counted once; then
## "whenever a creature attacks this turn" — one trigger per attacking
## creature (MC.attack_fan_out). With no creature card milled the triggers
## still happen, each giving +0/+0 (as printed).
class SongOfBlood extends MillEffect:
	func _init() -> void:
		super(4)
		target_spec = null
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var library := g.players[pid].library
		var top: Array[CardInstance] = []
		for n in mini(4, library.size()):
			top.append(library[library.size() - 1 - n])
		g.mill(pid, 4)
		var creatures := 0
		for card in top:
			if card.zone == Mtg.Zone.GRAVEYARD and card.data.is_creature():
				creatures += 1
		var entry := g.schedule_delayed_trigger(MC.attack_fan_out(_song_fan_out.bind(pid, creatures), Callable(),
			"Whenever a creature attacks this turn, it gets +%d/+0 until end of turn." % creatures), pid, s, true)
		entry["expires_turn"] = g.turn_number
	func describe() -> String:
		return "mill four cards; whenever a creature attacks this turn, it gets +1/+0 for each creature card milled this way"
	static func _song_fan_out(g: MtgGame, s: CardInstance, e: GameEvent, pid: int, bonus: int) -> void:
		for attacker in e.data.get("attackers", []):
			var i := attacker as CardInstance
			if i != null:
				MC.queue_for_attacker(g, s, e, pid, i, _song_pump,
					"Song of Blood: this attacking creature gets +%d/+0 until end of turn." % bonus, [bonus])
	static func _song_pump(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int, bonus: int) -> void:
		var i := MC.live(g, id, stamp)
		if i == null or bonus <= 0: return
		g.continuous.add_until_eot_pump(i.id, bonus, 0)
		g.recalculate()


static func _champion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := MC.pair_other_live(g, s)
	if other == null: return
	g.continuous.add_until_eot_loss(other.id, [Mtg.Keyword.FIRST_STRIKE])
	g.recalculate()


## Talruum Piper: a Lure narrowed to the creatures with flying (Marble
## Priest's shape); a Lure already asking EVERY creature is left alone.
static func _piper(_g: MtgGame, s: CardInstance) -> void:
	if s.cur_must_be_blocked_by_all or (s.cur_must_be_blocked and not s.cur_must_be_blocked_filter.is_valid()): return
	var before := s.cur_must_be_blocked_filter
	s.cur_must_be_blocked = true
	if not before.is_valid():
		s.cur_must_be_blocked_filter = MC.P.flying
	else:
		s.cur_must_be_blocked_filter = func(blocker: CardInstance) -> bool:
			return bool(before.call(blocker)) or MC.P.flying(blocker)


# ================================================================== green

## Elephant Grass: "attack you" — the creatures of the player who could
## attack its controller. The {2} per attacker is the declaration's
## combined attack cost (CR 508.1g; Koskun Falls' shape, hml/_worlds.gd).
static func _elephant_grass(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[g.opponent_of(s.controller_id)].battlefield:
		if not i.is_creature(): continue
		if MC.P.black(i):
			i.cur_cant_attack = true
		else:
			i.cur_attack_costs.append({"desc": "its controller pays {2} (Elephant Grass)",
				"generic_mana": 2, "can_pay": _can_pay_two, "pay": _pay_two})


static func _can_pay_two(g: MtgGame, who: int) -> bool:
	return g.can_afford_cost(who, ManaCost.parse("{2}"))


static func _pay_two(g: MtgGame, who: int) -> void:
	g.try_pay(who, ManaCost.parse("{2}"))


## Wind Shear: the attacking creatures with flying as it resolves (CR
## 611.2c) get -2/-2 and lose flying.
class WindShear extends MassPumpEffect:
	func _init() -> void:
		super(-2, -2, "attacking creatures with flying")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var hit: Array[CardInstance] = []
		for id in g.combat.attackers:
			var i := g.find_instance(int(id))
			if g.is_present(i) and i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING):
				hit.append(i)
		for i in hit:
			g.continuous.add_until_eot_pump(i.id, -2, -2)
			g.continuous.add_until_eot_loss(i.id, [Mtg.Keyword.FLYING])
		g.recalculate()
	func describe() -> String:
		return "attacking creatures with flying get -2/-2 and lose flying until end of turn"


# =================================================================== gold

## Pygmy Hippo. "You may have" is the Hippo controller's choice; the
## defending player then activates ONE mana ability of each land they
## control that can activate one (an already tapped land cannot pay {T}) —
## which one is theirs to choose — and loses every unspent mana in their
## pool, whatever it came from (CR 106.4). The Hippo assigns no combat
## damage; the mana returns as {C} at the controller's next main phase THIS
## turn (Mana Drain's delayed action, leg/mana_drain.gd), never later.
static func _hippo(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := MC.pid_of(g, s)
	var foe := g.opponent_of(pid)
	var lands: Array[CardInstance] = []
	var ready := 0
	for i in g.players[foe].battlefield:
		if i.is_land() and not i.cur_mana_abilities.is_empty():
			lands.append(i)
			if not i.tapped: ready += 1
	var power := maxi(0, s.cur_power if MC.same(g, s) else s.last_power)
	var hint := ready + g.players[foe].mana_pool.total() > power
	# MANA BURN (RulesOptions.mana_burn, either edition): the {C} burns
	# whatever of it is not spent in that main phase — never free mana.
	if hint and g.rules.mana_burn:
		hint = _hippo_burn_free(g, pid, _hippo_haul(g, foe, lands))
	if not g.agents[pid].choose_yes_no(g, pid,
			"Pygmy Hippo: make %s tap each land for mana and lose it, instead of assigning combat damage?" % g.players[foe].player_name,
			hint):
		return
	for land in lands:
		if g.is_present(land) and land.controller_id == foe:
			_activate_one(g, foe, land)
	var pool := g.players[foe].mana_pool
	var lost := pool.total()
	pool.clear()
	g.log_line("%s loses %d unspent mana (Pygmy Hippo)" % [g.players[foe].player_name, lost])
	if MC.same(g, s):
		MC.assigns_no_combat_damage(g, s)
	if lost <= 0: return
	# A WEAKREF, not `g` (leg/mana_drain.gd): the game holds the action.
	var weak: WeakRef = weakref(g)
	var turn := g.turn_number
	g.schedule_next_main_phase_action(pid, func() -> void:
		var game: MtgGame = weak.get_ref()
		if game == null or game.turn_number != turn:
			return
		game.players[pid].mana_pool.add(Mtg.ManaColor.C, lost)
		game.log_line("Pygmy Hippo: %s adds %d colorless" % [game.players[pid].player_name, lost]))


## The most mana [param foe] can be made to lose, and so the most {C} the
## Hippo's controller receives: their pool plus each land's LARGEST mana
## ability — which one is the defending player's choice, so the worst case
## is the one to plan for — a tapped land only through one without {T}.
static func _hippo_haul(g: MtgGame, foe: int, lands: Array[CardInstance]) -> int:
	var haul := g.players[foe].mana_pool.total()
	for land in lands:
		var most := 0
		for ability: ManaAbility in land.cur_mana_abilities:
			if land.tapped and ability.taps_source: continue
			var n := 0
			for k in ability.produces.size():
				n += ability.amount_for(g, land, foe) if k == 0 else int(ability.produces[k][1])
			most = maxi(most, n)
		haul += most
	return haul


## Under mana burn the Hippo's {C} arrives at the start of its controller's
## next main phase and whatever is not spent there burns them (CR 500.4,
## the 1997 rule). The hint takes it only when ONE sorcery-speed spell in
## the controller's own hand (its own cards: fair information, CONTRIBUTING
## rule 8) soaks up the whole [param haul] with its generic part, the rest
## of its cost payable from the controller's own sources — one spell, so
## two never count the same land — and never when the haul left unspent
## would be lethal, whatever the hand holds (the hand is a plan, not a
## promise: the AI may yet hold that spell).
static func _hippo_burn_free(g: MtgGame, pid: int, haul: int) -> bool:
	if haul <= 0: return true
	if haul >= g.players[pid].life: return false
	for card in g.players[pid].hand:
		if card.data.is_land() or card.data.is_type(Mtg.CardType.INSTANT): continue
		var cost := g.spell_cost_for(pid, card.data)
		if cost.generic < haul: continue
		var rest := cost.minus_generic(haul)
		rest.has_x = false
		rest.x_count = 0
		if g.can_afford_cost(pid, rest): return true
	return false


## One mana ability of [param land], the defending player's pick when it
## has several (the hint: the first without a life, mana or sacrifice
## cost); an ability that cannot be activated falls through to the next.
static func _activate_one(g: MtgGame, who: int, land: CardInstance) -> void:
	var count := land.cur_mana_abilities.size()
	var first := 0
	if count > 1:
		var labels: Array[String] = []
		var hint := -1
		for n in count:
			var ability: ManaAbility = land.cur_mana_abilities[n]
			labels.append(_mana_label(ability))
			if hint < 0 and ability.life_cost == 0 and ability.cost == null and not ability.sacrifice_source:
				hint = n
		first = g.agents[who].choose_option(g, who, labels,
			"Pygmy Hippo: activate which mana ability of %s?" % land.data.card_name, maxi(hint, 0))
	var order: Array[int] = [first]
	for n in count:
		if n != first: order.append(n)
	for n in order:
		if g.tap_for_mana(who, land, n) == "":
			return


static func _mana_label(ability: ManaAbility) -> String:
	var parts := PackedStringArray()
	for pair in ability.produces:
		parts.append("%d %s" % [int(pair[1]), str(Mtg.COLOR_NAMES.get(int(pair[0]), "mana"))])
	return "Add " + ", ".join(parts)

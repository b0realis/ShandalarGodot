extends RefCounted
## Urza's Destiny (_triggers, Pack 10). Triggered abilities: enters, leaves, dies, upkeep and spell triggers.
##
## The conventions of the Urza's Saga module (cards/sets/usg/_triggers.gd),
## whose shared helpers this reuses as U:
## - A "dies" trigger is heard by the departing card (CR 603.10a); "you" is
##   the seat that controlled the creature as it died (CR 603.3a), read as
##   M.pid_of on resolution. "You may exile it. If you do" (Academy Rector,
##   Gamekeeper) and "exile it" (Body Snatcher) act only on the card that
##   died THIS time, still in the graveyard it went to (CR 400.7); a card
##   that cannot be exiled is not "done", so nothing follows.
## - "When you control no <things>, sacrifice this creature" (Tethered
##   Griffin, Covetous Dragon, Emperor Crocodile) is the engine's sacrifice
##   clause (CardData.sacrifices_when): a state-based sacrifice by default,
##   a state trigger under RulesOptions.sacrifice_clauses_wait — never a
##   trigger of the card's own (tests/cards/test_c2_f_sac_family.gd).
## - An Aura put onto the battlefield without being cast (Academy Rector's
##   find, Iridescent Drake's) is not targeted: it needs an object it could
##   legally enchant, or it stays where it is (CR 303.4f-g).
## - Rayne reads "if Rayne is enchanted" as the ability resolves — while it
##   is still the object that triggered — else as it last existed (CR
##   608.2h): the leave hook records that before its Auras are put into
##   the graveyard.
## tests/cards/test_pack_10_B5_*.gd pin every card here.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const U := preload("res://cards/sets/usg/_triggers.gd")
const OC := preload("res://engine/additional_object_costs.gd")
const EUREKA := preload("res://cards/sets/leg/eureka.gd")

const ETB := Mtg.EventType.ENTERS_BATTLEFIELD
const DIES := Mtg.EventType.DIES
const UPKEEP := Mtg.EventType.UPKEEP_START

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Academy Rector":
			c.triggered(TriggeredAbility.new(DIES, _rector,
				"When this creature dies, you may exile it. If you do, search your library for an enchantment card, put that card onto the battlefield, then shuffle.",
				F._self_enter).capturing(M._dead_context))
		"False Prophet":
			c.triggered(TriggeredAbility.new(DIES, _false_prophet,
				"When this creature dies, exile all creatures.", F._self_enter))
		"Reliquary Monk":
			c.triggered(TriggeredAbility.new(DIES, U.destroy_targets,
				"When this creature dies, destroy target artifact or enchantment.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or enchantment",
					U.artifact_or_enchantment), U.theirs_first,
					"Reliquary Monk: select target artifact or enchantment to destroy."))
		"Tethered Griffin":
			# The scaffold prints flying.
			c.sacrifices_when(_no_enchantments)
		# ------------------------------------------------------------- blue
		"Aura Thief":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(DIES, _aura_thief,
				"When this creature dies, you gain control of all enchantments. (You don't get to move Auras.)",
				F._self_enter))
		"Iridescent Drake":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(ETB, _iridescent,
				"When this creature enters, put target Aura card from a graveyard onto the battlefield under your control attached to this creature.",
				F._self_enter).targeting(TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD,
					"target Aura card from a graveyard", _aura_card), _drake_aura_order,
					"Iridescent Drake: select target Aura card in a graveyard."))
		"Kingfisher":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(DIES, U.draw_one,
				"When this creature dies, draw a card.", F._self_enter))
		"Rayne, Academy Chancellor":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _rayne,
				"Whenever you or a permanent you control becomes the target of a spell or ability an opponent controls, you may draw a card. You may draw an additional card if Rayne is enchanted.",
				_rayne_targeted).capturing(_rayne_context))
			c.as_it_leaves(_rayne_leaves)
		"Telepathic Spies":
			c.triggered(TriggeredAbility.new(ETB, _spies,
				"When this creature enters, look at target opponent's hand.", F._self_enter) \
				.targeting(TargetSpec.opponent(), Callable(), "Telepathic Spies: select target opponent."))
		"Thieving Magpie":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, U.draw_one,
				"Whenever this creature deals damage to an opponent, draw a card.", U.hits_an_opponent))
		# ------------------------------------------------------------ black
		"Apprentice Necromancer":
			c.activated(ActivatedAbility.new("{B}", true, [NecromancerRaise.new()],
				"{B}, {T}, Sacrifice this creature: Return target creature card from your graveyard to the battlefield. That creature gains haste. At the beginning of the next end step, sacrifice it.") \
				.with_sacrifice_cost())
		"Body Snatcher":
			c.triggered(TriggeredAbility.new(ETB, _snatcher_enters,
				"When this creature enters, exile it unless you discard a creature card.", F._self_enter))
			c.triggered(TriggeredAbility.new(DIES, _snatcher_dies,
				"When this creature dies, exile it and return target creature card from your graveyard to the battlefield.",
				F._self_enter).capturing(M._dead_context) \
				.targeting(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
					"target creature card from your graveyard"), _snatcher_order,
					"Body Snatcher: select target creature card in your graveyard."))
		"Disease Carriers":
			c.triggered(TriggeredAbility.new(DIES, U.pump_targets.bind(-2, -2),
				"When this creature dies, target creature gets -2/-2 until end of turn.", F._self_enter) \
				.targeting(TargetSpec.creature(), U.theirs_first, "Disease Carriers: select target creature."))
		"Phyrexian Negator":
			# The scaffold prints trample.
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _negator,
				"Whenever this creature is dealt damage, sacrifice that many permanents.",
				_dealt_damage_me).capturing(_amount_context))
		"Plague Dogs":
			c.triggered(TriggeredAbility.new(DIES, _plague_dogs,
				"When this creature dies, all creatures get -1/-1 until end of turn.", F._self_enter))
			c.activated(_sacrifice_draw())
		"Skittering Horror":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, M.sacrifice_source,
				"When you cast a creature spell, sacrifice this creature.", U.you_cast_a_creature_spell))
		# -------------------------------------------------------------- red
		"Covetous Dragon":
			# The scaffold prints flying.
			c.sacrifices_when(_no_artifacts)
		"Goblin Gardener":
			c.triggered(TriggeredAbility.new(DIES, U.destroy_targets,
				"When this creature dies, destroy target land.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", U.land), U.theirs_first,
					"Goblin Gardener: select target land to destroy."))
		"Goblin Masons":
			c.triggered(TriggeredAbility.new(DIES, U.destroy_targets,
				"When this creature dies, destroy target Wall.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Wall", _wall).only_walls(),
					U.theirs_first, "Goblin Masons: select target Wall to destroy."))
		# ------------------------------------------------------------ green
		"Emperor Crocodile":
			c.sacrifices_when(_no_other_creatures)
		"Gamekeeper":
			c.triggered(TriggeredAbility.new(DIES, _gamekeeper,
				"When this creature dies, you may exile it. If you do, reveal cards from the top of your library until you reveal a creature card. Put that card onto the battlefield and put all other cards revealed this way into your graveyard.",
				F._self_enter).capturing(M._dead_context))
		"Marker Beetles":
			c.triggered(TriggeredAbility.new(DIES, U.pump_targets.bind(1, 1),
				"When this creature dies, target creature gets +1/+1 until end of turn.", F._self_enter) \
				.targeting(TargetSpec.creature(), M.friendly_first, "Marker Beetles: select target creature."))
			c.activated(_sacrifice_draw())
		"Yavimaya Elder":
			c.triggered(TriggeredAbility.new(DIES, _elder,
				"When this creature dies, you may search your library for up to two basic land cards, reveal them, put them into your hand, then shuffle.",
				F._self_enter))
			c.activated(_sacrifice_draw())
		# --------------------------------------------------------- artifact
		"Junk Diver":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(DIES, U.return_card_targets,
				"When this creature dies, return another target artifact card from your graveyard to your hand.",
				F._self_enter).targeting(U.graveyard_card_spec(Mtg.CardType.ARTIFACT,
					"another target artifact card from your graveyard").with_source_filter(U.not_source),
					U.best_card_first, "Junk Diver: select another target artifact card in your graveyard."))
		"Masticore":
			c.triggered(TriggeredAbility.new(UPKEEP, _masticore,
				"At the beginning of your upkeep, sacrifice this creature unless you discard a card.", F._your_upkeep))
			c.activated(ActivatedAbility.new("{2}", false, [DamageEffect.new(1).target_creature()],
				"{2}: This creature deals 1 damage to target creature."))
			c.activated(ActivatedAbility.new("{2}", false, [RegenerateEffect.new()],
				"{2}: Regenerate this creature."))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## "{2}, Sacrifice this creature: Draw a card." (Plague Dogs, Marker
## Beetles, Yavimaya Elder) — built fresh per card.
static func _sacrifice_draw() -> ActivatedAbility:
	return ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
		"{2}, Sacrifice this creature: Draw a card.").with_sacrifice_cost()

## The card that died THIS time, still in the graveyard it went to (CR
## 400.7), exiled; true when it now is in exile ("if you do").
static func _exile_the_corpse(g: MtgGame, s: CardInstance) -> bool:
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(g.trigger_context(s).get("entry", -1)):
		return false
	g.exile_from_graveyard(s)
	return s.zone == Mtg.Zone.EXILE

static func _controls(g: MtgGame, pid: int, filter: Callable) -> bool:
	for i in g.players[pid].battlefield:
		if g.is_present(i) and filter.call(i): return true
	return false


# -------------------------------------------------------------- Academy Rector --

## An enchantment card the search may take: an Aura only when it could be
## attached to something as it enters (CR 303.4f) — otherwise it would have
## to stay in the library, so it is not offered.
static func _rector_find(g: MtgGame, card: CardInstance) -> bool:
	if not card.data.is_type(Mtg.CardType.ENCHANTMENT): return false
	return not card.data.is_aura() or not EUREKA.EurekaEffect._hosts(g, card).is_empty()

## "You may exile it. If you do, search ..." — the search is a hidden-zone
## choice of the controller's own library (fair). An Aura found enters
## attached to an object its controller chooses (Eureka's host list and
## hint); anything else enters on its own. "Then shuffle" (pick_from_library
## shuffles).
static func _rector(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var ctx := g.trigger_context(s)
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(ctx.get("entry", -1)): return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Exile Academy Rector to search your library for an enchantment card and put it onto the battlefield?",
			not g.players[pid].library.is_empty()):
		return
	if not _exile_the_corpse(g, s): return
	var found := g.pick_from_library(pid, func(card: CardInstance) -> bool: return _rector_find(g, card),
		"Academy Rector: search your library for an enchantment card")
	if found == null: return
	if not found.data.is_aura():
		g.put_into_play(found, pid)
		return
	var hosts := EUREKA.EurekaEffect._hosts(g, found)
	if hosts.is_empty(): return
	var friendly := EffectIntent.aura_aim(found.data) != EffectIntent.Aim.HOSTILE
	hosts.sort_custom(EUREKA.EurekaEffect._host_order.bind(pid, friendly))
	var host := M.pick(g, pid, hosts, "Choose what %s enchants" % found.data.card_name)
	g.attach_aura_from_anywhere(found, host, pid)


# --------------------------------------------------------------- False Prophet --

## One simultaneous departure (CR 603.10a for their own triggers): exile,
## so regeneration does not help and tokens cease to exist.
static func _false_prophet(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var victims: Array = []
	for i in g.all_battlefield():
		if i.is_creature() and g.is_present(i): victims.append(i)
	if victims.is_empty(): return
	g.depart_together(victims, func(i: CardInstance) -> void: g.exile_permanent(i))


# ------------------------------------------------------------ Tethered Griffin --

static func _no_enchantments(g: MtgGame, s: CardInstance) -> bool:
	return not _controls(g, s.controller_id, U.enchantment)


# ------------------------------------------------------------------ Aura Thief --

## "You gain control of all enchantments" — indefinitely, every enchantment
## on the battlefield (an animated one too); Auras stay where they are.
static func _aura_thief(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var taken: Array[CardInstance] = []
	for i in g.all_battlefield():
		if g.is_present(i) and i.is_type(Mtg.CardType.ENCHANTMENT) and i.controller_id != pid:
			taken.append(i)
	for i in taken:
		if g.is_present(i): g.change_control(i, pid)


# ------------------------------------------------------------ Iridescent Drake --

static func _aura_card(i: CardInstance) -> bool: return i.data.is_aura()

## Auras that can enchant the Drake first (one that cannot is a legal target
## but stays in its graveyard), helpful ones before hostile, costliest first.
static func _drake_aura_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _drake_value(g, s, a) > _drake_value(g, s, b)

static func _drake_value(g: MtgGame, s: CardInstance, ref: TargetRef) -> int:
	var aura := g.find_instance(ref.instance_id)
	if aura == null: return -1000
	var value := aura.data.cost.mana_value()
	if g.is_present(s) and g.aura_can_enchant(aura, s): value += 100
	if EffectIntent.aura_aim(aura.data) != EffectIntent.Aim.HOSTILE: value += 50
	return value

## "Under your control attached to this creature": only while the Drake is
## the object that triggered, and only an Aura that could legally enchant
## it (CR 303.4f-g) — from either graveyard.
static func _iridescent(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	for t in g.current_targets():
		var aura := g.find_instance((t as TargetRef).instance_id)
		if aura == null or aura.zone != Mtg.Zone.GRAVEYARD: continue
		if not g.aura_can_enchant(aura, s) or (s.cur_protection & aura.cur_colors) != 0: continue
		g.attach_aura_from_anywhere(aura, s, M.pid_of(g, s))


# ---------------------------------------------------- Rayne, Academy Chancellor --

## "You or a permanent you control becomes the target of a spell or
## ability an opponent controls" — once per targeted object per stack
## object (BECAME_TARGET).
static func _rayne_targeted(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var by := int(e.data.get("controller", -1))
	if by < 0 or by == s.controller_id: return false
	if int(e.data.get("player", -1)) == s.controller_id: return true
	var i: CardInstance = e.data.get("instance")
	return i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.controller_id == s.controller_id

static func _rayne_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["enchanted"] = g.is_enchanted(s)
	return ctx

## As Rayne leaves, her Auras are still attached (their state-based
## departure comes later): record whether she was enchanted as she last
## existed, for a trigger still waiting to resolve.
static func _rayne_leaves(g: MtgGame, inst: CardInstance, _controller: int, _memory: Dictionary) -> void:
	var enchanted := false
	for i in g.all_battlefield():
		if i.is_aura() and i.attached_to == inst.id and not i.phased_out:
			enchanted = true
			break
	g._rec(inst, &"memory")
	inst.memory["rayne_left"] = {"stamp": inst.layer_timestamp, "enchanted": enchanted}

static func _rayne_enchanted(g: MtgGame, s: CardInstance) -> bool:
	var ctx := g.trigger_context(s)
	if F._same_trigger_object(g, s): return g.is_enchanted(s)
	var left: Dictionary = s.memory.get("rayne_left", {})
	if int(left.get("stamp", -1)) == int(ctx.get("timestamp", -2)):
		return bool(left.get("enchanted", false))
	return bool(ctx.get("enchanted", false))

## Two separate "may"s; the additional card only after the first, and only
## if Rayne is enchanted as the ability resolves.
static func _rayne(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not g.agents[pid].choose_yes_no(g, pid, "Rayne, Academy Chancellor: draw a card?",
			not g.players[pid].library.is_empty()):
		return
	g.draw_cards(pid, 1)
	if _rayne_enchanted(g, s) and g.agents[pid].choose_yes_no(g, pid,
			"Rayne, Academy Chancellor is enchanted: draw an additional card?",
			not g.players[pid].library.is_empty()):
		g.draw_cards(pid, 1)


# ------------------------------------------------------------ Telepathic Spies --

## A private look for the Spies' controller only (a reveal the rules permit,
## so an AI may remember it — fair play).
static func _spies(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	for t in g.current_targets():
		var who := (t as TargetRef).player_id
		if who < 0: continue
		var names: Array = []
		for card in g.players[who].hand: names.append(card.data.card_name)
		g.reveal_information(pid, "Telepathic Spies — %s's hand" % g.players[who].player_name, names)
		g.log_line("%s looks at %s's hand (Telepathic Spies)" % [g.players[pid].player_name, g.players[who].player_name])


# ------------------------------------------------------ Apprentice Necromancer --

## Targets a creature card in the activator's graveyard — chosen before the
## sacrifice is paid (CR 602.2b), so never the Necromancer itself. The
## haste has no duration (it lasts while that object stays, CR 611.2), and
## "sacrifice it" at the next end step is the activator's, only while they
## still control it (CR 603.7d, 701.17a).
class NecromancerRaise extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		to_battlefield_mode = true
		ai_helpful = true
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var card := g.find_instance(t.instance_id) if t != null else null
		if card == null or card.zone != Mtg.Zone.GRAVEYARD: return
		g.reanimate(card, pid)
		if not g.is_present(card): return
		g.grant_keyword_permanently(card, Mtg.Keyword.HASTE)
		g.doom_at_next_end_step(card, false, false, true, pid)
	func describe() -> String:
		return "return target creature card from your graveyard to the battlefield; it gains haste; sacrifice it at the beginning of the next end step"


# --------------------------------------------------------------- Body Snatcher --

static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()

## "Exile it unless you discard a creature card" — a payment made on
## resolution; a Snatcher that has left has nothing to keep and is not
## asked. The hint keeps it.
static func _snatcher_enters(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not F._same_trigger_source(g, s) or s.controller_id != pid: return
	if g.unless_objects_paid(pid, s, [OC.discarding("creature card", _creature_card)],
			"Body Snatcher: discard a creature card? (otherwise exile Body Snatcher)", true):
		return
	g.exile_permanent(s)

## The Snatcher's own card is a legal target too (it is a creature card in
## the graveyard) but is exiled first, so it is offered last; the biggest
## other body first.
static func _snatcher_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	if (ai == s) != (bi == s): return bi == s
	return ai.data.power + ai.data.toughness + ai.data.cost.mana_value() \
		> bi.data.power + bi.data.toughness + bi.data.cost.mana_value()

## "Exile it and return target creature card": the corpse is exiled if it
## is still the card that died (CR 400.7), and the target returns either way
## — under the control of the trigger's controller.
static func _snatcher_dies(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	_exile_the_corpse(g, s)
	var pid := M.pid_of(g, s)
	for t in g.current_targets():
		var card := g.find_instance((t as TargetRef).instance_id)
		if card != null and card.zone == Mtg.Zone.GRAVEYARD:
			g.reanimate(card, pid)


# ----------------------------------------------------------- Phyrexian Negator --

static func _dealt_damage_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("to_instance") == s and int(e.data.get("amount", 0)) > 0

static func _amount_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["amount"] = int(e.data.get("amount", 0))
	return ctx

## "Sacrifice that many permanents" — the trigger's controller chooses
## them (the Negator itself among them), as many as they have.
static func _negator(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var amount := int(g.trigger_context(s).get("amount", 0))
	if amount <= 0: return
	U.sacrifice_some(g, M.pid_of(g, s), func(_i: CardInstance) -> bool: return true,
		"Phyrexian Negator: sacrifice a permanent", amount)


# ----------------------------------------------------------------- Plague Dogs --

## The affected set is fixed as it resolves (CR 611.2c).
static func _plague_dogs(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	MassPumpEffect.new(-1, -1).resolve(g, s, M.pid_of(g, s), null)


# ------------------------------------------------------------- Covetous Dragon --

static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)

static func _no_artifacts(g: MtgGame, s: CardInstance) -> bool:
	return not _controls(g, s.controller_id, _artifact)


# --------------------------------------------------------------- Goblin Masons --

static func _wall(i: CardInstance) -> bool: return i.has_subtype("wall")


# ----------------------------------------------------------- Emperor Crocodile --

static func _no_other_creatures(g: MtgGame, s: CardInstance) -> bool:
	return not _controls(g, s.controller_id, func(i: CardInstance) -> bool: return i != s and i.is_creature())


# ------------------------------------------------------------------ Gamekeeper --

## "You may exile it. If you do, reveal ... until a creature card" — the
## Avenging Druid shape (exo/_triggers.gd): every revealed card is public;
## with no creature card in the library every card is revealed and goes to
## the graveyard.
static func _gamekeeper(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var ctx := g.trigger_context(s)
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(ctx.get("entry", -1)): return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Exile Gamekeeper to reveal cards from the top of your library until you reveal a creature card?",
			not g.players[pid].library.is_empty()):
		return
	if not _exile_the_corpse(g, s): return
	var library := g.players[pid].library
	var revealed: Array[CardInstance] = []
	var found: CardInstance = null
	for n in range(library.size() - 1, -1, -1):
		var card: CardInstance = library[n]
		revealed.append(card)
		if card.data.is_creature():
			found = card
			break
	if revealed.is_empty(): return
	var names: Array = []
	for card in revealed: names.append(card.data.card_name)
	g.reveal_information(-1, "Gamekeeper reveals", names)
	g.log_line("%s reveals %s (Gamekeeper)" % [g.players[pid].player_name, ", ".join(PackedStringArray(names))])
	if found != null:
		g.put_library_card_onto_battlefield(found, pid)
	for card in revealed:
		if card != found: g.put_library_card_into_graveyard(card)


# -------------------------------------------------------------- Yavimaya Elder --

static func _basic_land_card(card: CardInstance) -> bool:
	return card.data.is_land() and (card.data.supertypes & Mtg.Supertype.BASIC) != 0

## "Up to two", revealed, into the hand; one shuffle after the whole search
## (CR 701.19a — Land Tax's shape).
static func _elder(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not g.agents[pid].choose_yes_no(g, pid,
			"Yavimaya Elder: search your library for up to two basic land cards?",
			not g.players[pid].library.is_empty()):
		return
	for n in 2:
		g.search_library(pid, _basic_land_card,
			"Yavimaya Elder: search for a basic land card (%d of up to 2)" % (n + 1), false, false,
			"Yavimaya Elder reveals")
	g.shuffle_library(pid)


# ------------------------------------------------------------------- Masticore --

## "Unless you discard a card" — an "unless" payment (CR 118.12): not a
## discard an effect causes, so Library of Leng has no say, and a discard
## watcher (Megrim) still sees it. The hint keeps the Masticore.
static func _masticore(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not F._same_trigger_source(g, s) or s.controller_id != pid: return
	if g.unless_objects_paid(pid, s, [OC.discarding("card")],
			"Masticore: discard a card? (otherwise sacrifice Masticore)", true):
		return
	g.sacrifice_permanent(s)

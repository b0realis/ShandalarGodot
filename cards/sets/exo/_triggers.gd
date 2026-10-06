extends RefCounted
## Exodus (_triggers, Pack 9). Triggered abilities: enters, dies, upkeep, end step and other event triggers.
##
## Same conventions as the Mirage block modules (cards/sets/mir/_triggers.gd,
## whose shared helpers this reuses as M):
## - A triggered ability exists apart from its source (CR 603.6 / 608.2h):
##   it resolves even when the source has left, acting for the seat that
##   controlled it (M.pid_of) and dealing damage from the source as it last
##   existed. Only the clauses that name the source itself ("return this
##   creature", "sacrifice it", "put counters on this creature") check that
##   the very same object is still there (F._same_trigger_source).
## - An intervening "if" (CR 603.4 — Convalescence, Zealots en-Dal) is the
##   trigger's condition AND a recheck on resolution.
## - A targeted trigger's target is chosen as it goes on the stack (CR
##   603.3d); a "you may" in its text is answered on resolution (Anarchist,
##   Cartographer, Scrivener, Treasure Hunter, Equilibrium's {1}).
## - Per-occurrence facts (the creature Pit Spawn damaged, the creature that
##   entered under Pandemonium) are captured as the ability triggers.
## - "Whenever a player casts a spell" hears SPELL_CAST, whose `controller`
##   is the caster (Mana Breach, Spellshock).
##
## PANDEMONIUM (engine package E7, TriggeredAbility.chosen_by): the trigger
## is Pandemonium's controller's, but the entering creature's controller
## chooses its target (CR 603.3d — "any target of THEIR choice") and
## answers the "may" on resolution. The damage is the creature's, equal to
## its power — its last known power if it has left (CR 608.2h).
##
## tests/cards/test_pack_9_B11_triggers.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Convalescence":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _convalescence,
				"At the beginning of your upkeep, if you have 10 or less life, you gain 1 life.", _convalescence_if))
		"Soul Warden":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, M._gain_life.bind(1),
				"Whenever another creature enters, you gain 1 life.", _another_creature_enters))
		"Treasure Hunter":
			_salvage(c, "artifact", Mtg.CardType.ARTIFACT)
		"Welkin Hawk":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _welkin_hawk,
				"When this creature dies, you may search your library for a card named Welkin Hawk, reveal that card, put it into your hand, then shuffle.",
				F._self_enter))
		"Zealots en-Dal":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _zealots,
				"At the beginning of your upkeep, if all nonland permanents you control are white, you gain 1 life.", _zealots_if))
		# ----------------------------------------------------------- blue
		"Equilibrium":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _equilibrium,
				"Whenever you cast a creature spell, you may pay {1}. If you do, return target creature to its owner's hand.",
				_you_cast_a_creature_spell).targeting(TargetSpec.creature(), _theirs_first,
				"Equilibrium: select target creature to return to its owner's hand."))
		"Mana Breach":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _mana_breach,
				"Whenever a player casts a spell, that player returns a land they control to its owner's hand."))
		"Mirozel":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _self_to_hand,
				"When this creature becomes the target of a spell or ability, return this creature to its owner's hand.",
				M.targeted_me))
		"School of Piranha":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{1}{U}"),
				"At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.", F._your_upkeep))
		"Scrivener":
			_salvage(c, "instant", Mtg.CardType.INSTANT)
		# ---------------------------------------------------------- black
		"Carnophage":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _carnophage,
				"At the beginning of your upkeep, tap this creature unless you pay 1 life.", F._your_upkeep))
		"Grollub":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _grollub,
				"Whenever this creature is dealt damage, each opponent gains that much life.", _dealt_damage_me))
		"Mind Maggots":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _mind_maggots,
				"When this creature enters, discard any number of creature cards. For each card discarded this way, put two +1/+1 counters on this creature.",
				F._self_enter))
		"Pit Spawn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{B}{B}"),
				"At the beginning of your upkeep, sacrifice this creature unless you pay {B}{B}.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _pit_spawn,
				"Whenever this creature deals damage to a creature, exile that creature.",
				_damages_a_creature).capturing(_victim_context).public_aftermath())
		# ------------------------------------------------------------ red
		"Anarchist":
			_salvage(c, "sorcery", Mtg.CardType.SORCERY)
		"Onslaught":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _tap_target,
				"Whenever you cast a creature spell, tap target creature.",
				_you_cast_a_creature_spell).targeting(TargetSpec.creature(), _untapped_foe_first,
				"Onslaught: select target creature to tap."))
		"Pandemonium":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _pandemonium,
				"Whenever a creature enters, that creature's controller may have it deal damage equal to its power to any target of their choice.",
				_a_creature_enters).capturing(_entrant_context) \
				.targeting(TargetSpec.any_target(), _pandemonium_order,
					"Pandemonium: select any target for the entering creature's damage.") \
				.chosen_by(_entering_controller))
		"Ravenous Baboons":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _destroy_target,
				"When this creature enters, destroy target nonbasic land.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nonbasic land", _nonbasic_land),
					_theirs_first, "Ravenous Baboons: select target nonbasic land to destroy."))
		"Spellshock":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _spellshock,
				"Whenever a player casts a spell, this enchantment deals 2 damage to that player."))
		# ---------------------------------------------------------- green
		"Avenging Druid":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _avenging_druid,
				"Whenever this creature deals damage to an opponent, you may reveal cards from the top of your library until you reveal a land card. If you do, put that card onto the battlefield and put all other cards revealed this way into your graveyard.",
				_damages_an_opponent))
		"Cartographer":
			_salvage(c, "land", Mtg.CardType.LAND)
		"Jackalope Herd":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _self_to_hand,
				"When you cast a spell, return this creature to its owner's hand.", _you_cast_a_spell))
		"Manabond":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _manabond,
				"At the beginning of your end step, you may reveal your hand and put all land cards from it onto the battlefield. If you do, discard your hand.",
				F._your_upkeep))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

static func _nonbasic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0

static func _another_creature_enters(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i != s and i.is_creature()

static func _a_creature_enters(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i.is_creature()

static func _you_cast_a_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("controller", -1)) == s.controller_id

static func _you_cast_a_creature_spell(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return _you_cast_a_spell(g, s, e) and spell != null and spell.is_creature()

static func _dealt_damage_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("to_instance") == s and int(e.data.get("amount", 0)) > 0

static func _damages_an_opponent(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and int(e.data.get("amount", 0)) > 0 \
		and e.data.has("to_player") and int(e.data.to_player) != s.controller_id

## "Return this creature to its owner's hand" — only the object that
## triggered (CR 400.7).
static func _self_to_hand(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.return_to_hand(s)

## A targeted trigger's preference for a HARMFUL target: the other side's
## permanents first, the costliest first; then our own, the cheapest first.
static func _theirs_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _harm_value(g, g.controller_acting_for(s), a) > _harm_value(g, g.controller_acting_for(s), b)

static func _harm_value(g: MtgGame, me: int, ref: TargetRef) -> float:
	var i := g.find_instance(ref.instance_id) if not ref.is_player else null
	if i == null: return -10000.0
	var worth := float(i.data.cost.mana_value()) + (float(i.cur_power + i.cur_toughness) if i.is_creature() else 0.0)
	return 1000.0 + worth if i.controller_id != me else -worth

## Onslaught: an opposing UNTAPPED creature first (the biggest), then any
## opposing one, then one of ours that is already tapped, an untapped one
## of ours last.
static func _untapped_foe_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _tap_value(g, g.controller_acting_for(s), a) > _tap_value(g, g.controller_acting_for(s), b)

static func _tap_value(g: MtgGame, me: int, ref: TargetRef) -> float:
	var i := g.find_instance(ref.instance_id) if not ref.is_player else null
	if i == null: return -10000.0
	var body := float(i.cur_power + i.cur_toughness)
	if i.controller_id != me:
		return (2000.0 if not i.tapped else 1000.0) + body
	return (0.0 if i.tapped else -1000.0) - body

static func _destroy_target(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if victim != null: g.destroy(victim)

static func _tap_target(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if g.is_present(victim): g.tap_permanent(victim)


# ------------------------------- Anarchist, Cartographer, Scrivener, Treasure Hunter --

## "When this creature enters, you may return target <kind> card from your
## graveyard to your hand": the target is chosen as the trigger goes on the
## stack (none: the trigger is removed, CR 603.3d), the "may" on resolution.
static func _salvage(c: CardData, kind: String, type: int) -> void:
	var spec := TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD,
		"target %s card from your graveyard" % kind, _card_of_type.bind(type))
	c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _salvage_resolve,
		"When this creature enters, you may return target %s card from your graveyard to your hand." % kind,
		F._self_enter).targeting(spec, _best_card_first, "Select target %s card in your graveyard." % kind))

## A card in a graveyard has only its printed characteristics.
static func _card_of_type(i: CardInstance, type: int) -> bool:
	return i.data.is_type(type)

static func _best_card_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	return ai.data.cost.mana_value() > bi.data.cost.mana_value()

static func _salvage_resolve(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var card := g.find_instance((targets[0] as TargetRef).instance_id)
	if card == null or card.zone != Mtg.Zone.GRAVEYARD: return
	var pid := M.pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "%s: return %s from your graveyard to your hand?" % [
			s.data.card_name, card.data.card_name], true):
		g.return_from_graveyard_to_hand(card)


# ----------------------------------------------------------- Avenging Druid --

## "You may reveal until a land": the hint asks the seat's own DECKLIST
## whether a land is still unaccounted for (fair information — never the
## library's order or contents). The land enters under the trigger's
## controller; every other revealed card goes to the graveyard — all of
## them when no land turns up ("if you do" is the reveal).
static func _avenging_druid(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var library := g.players[pid].library
	if library.is_empty(): return
	var hint := library.size() > 8 and _lands_unseen(g, pid) > 0
	if not g.agents[pid].choose_yes_no(g, pid,
			"Avenging Druid: reveal cards from the top of your library until you reveal a land card?", hint):
		return
	var revealed: Array[CardInstance] = []
	var found: CardInstance = null
	for n in range(library.size() - 1, -1, -1):
		var card: CardInstance = library[n]
		revealed.append(card)
		if card.data.is_land():
			found = card
			break
	var names: Array = []
	for card in revealed: names.append(card.data.card_name)
	g.reveal_information(-1, "Avenging Druid reveals", names)
	g.log_line("%s reveals %s (Avenging Druid)" % [g.players[pid].player_name, ", ".join(PackedStringArray(names))])
	if found != null:
		g.put_library_card_onto_battlefield(found, pid)
	for card in revealed:
		if card != found: g.put_library_card_into_graveyard(card)

## Land cards of [param pid]'s registered decklist not accounted for by a
## zone they can see (B12's Oath of Druids accounting, for lands). No
## decklist: "maybe one".
static func _lands_unseen(g: MtgGame, pid: int) -> int:
	var p := g.players[pid]
	if p.deck_names.is_empty():
		return 1
	var left := {}
	for card_name in p.deck_names:
		var data := CardRegistry.get_card(card_name)
		if data != null and data.is_land(): left[card_name] = int(left.get(card_name, 0)) + 1
	var known: Array = p.hand.duplicate()
	for player in g.players:
		for zone in [player.battlefield, player.graveyard, player.exile, player.ante]:
			for inst in zone:
				if not inst.face_down: known.append(inst)
	for inst in known:
		if inst.is_token or inst.owner_id != pid: continue
		var card_name: String = inst.data.card_name
		if left.has(card_name): left[card_name] = maxi(int(left[card_name]) - 1, 0)
	var total := 0
	for card_name in left: total += int(left[card_name])
	return total


# --------------------------------------------------------------- Carnophage --

## "Tap this creature unless you pay 1 life": paying life needs that much
## life (CR 119.4). The hint pays while the life is plentiful and the body
## is untapped (an already tapped Carnophage has nothing to keep).
static func _carnophage(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := M.pid_of(g, s)
	var life := g.players[pid].life
	if life >= 1 and g.agents[pid].choose_yes_no(g, pid,
			"Carnophage: pay 1 life? (Otherwise tap it.)", life > 5 and not s.tapped):
		g.adjust_life(pid, -1)
		return
	g.tap_permanent(s)


# ------------------------------------------------------------ Convalescence --

static func _convalescence_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and g.players[s.controller_id].life <= 10

## The intervening "if", rechecked on resolution (CR 603.4).
static func _convalescence(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if g.players[pid].life <= 10:
		g.adjust_life(pid, 1)


# -------------------------------------------------------------- Equilibrium --

## "You may pay {1}. If you do, return target creature" — the payment is
## made on resolution. The hint pays to bounce somebody else's creature.
static func _equilibrium(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var creature := g.find_instance((targets[0] as TargetRef).instance_id)
	if not g.is_present(creature): return
	var pid := M.pid_of(g, s)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{1}"),
			"Equilibrium: pay {1} to return %s to its owner's hand?" % creature.data.card_name,
			creature.controller_id != pid):
		g.return_to_hand(creature)


# ------------------------------------------------------------------ Grollub --

## "Each opponent gains that much life" — the opponents of the seat that
## controlled the trigger; "that much" is the one damage event's amount.
static func _grollub(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var amount := int(e.data.get("amount", 0))
	if amount <= 0: return
	var pid := M.pid_of(g, s)
	for p in g.players:
		if p.id != pid and not p.has_lost:
			g.adjust_life(p.id, amount)


# -------------------------------------------------------------- Mana Breach --

## "That player returns a land they control" — the caster's choice among
## their lands, offered cheapest-to-lose first: a tapped land before an
## untapped one, a basic before a nonbasic.
static func _mana_breach(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who < 0 or who >= g.players.size(): return
	var lands: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_land() and g.is_present(i): lands.append(i)
	if lands.is_empty(): return
	lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if a.tapped != b.tapped: return a.tapped
		var a_basic := (a.cur_supertypes & Mtg.Supertype.BASIC) != 0
		var b_basic := (b.cur_supertypes & Mtg.Supertype.BASIC) != 0
		return a_basic and not b_basic)
	g.return_to_hand(M.pick(g, who, lands, "Mana Breach: return a land you control to its owner's hand"))


# ----------------------------------------------------------------- Manabond --

## "You may reveal your hand and put all land cards from it onto the
## battlefield. If you do, discard your hand." The hint takes it only for a
## hand of lands alone (nothing else is thrown away).
static func _manabond(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var hand := g.players[pid].hand
	if hand.is_empty(): return
	var lands: Array[CardInstance] = []
	for card in hand:
		if card.data.is_land(): lands.append(card)
	if not g.agents[pid].choose_yes_no(g, pid,
			"Manabond: reveal your hand, put all land cards from it onto the battlefield, then discard your hand?",
			not lands.is_empty() and lands.size() == hand.size()):
		return
	var names: Array = []
	for card in hand: names.append(card.data.card_name)
	g.reveal_information(-1, "Manabond — %s's hand" % g.players[pid].player_name, names)
	g.log_line("%s reveals their hand (Manabond): %s" % [g.players[pid].player_name, ", ".join(PackedStringArray(names))])
	for land in lands:
		g.put_from_hand_into_play(land, pid)
	g.discard_hand(pid)


# ------------------------------------------------------------- Mind Maggots --

## "Discard any number of creature cards" — how many, then which, through
## the funnel. The counters go on this creature only if it is still the
## object that triggered; the discard is offered either way (it may feed a
## graveyard). Hint, from the seat's own hand and public board: the creature
## cards it could not cast next turn.
static func _mind_maggots(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var creatures: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_creature(): creatures.append(card)
	if creatures.is_empty(): return
	var present := F._same_trigger_source(g, s)
	var lands := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): lands += 1
	creatures.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() > b.data.cost.mana_value())
	var hint := 0
	if present:
		for card in creatures:
			if card.data.cost.mana_value() > lands + 1: hint += 1
	var count := g.agents[pid].choose_number(g, pid, 0, creatures.size(),
		"Mind Maggots: discard how many creature cards? (Two +1/+1 counters each.)", hint)
	var thrown: Array[CardInstance] = []
	for n in count:
		if creatures.is_empty(): break
		var pick := M.pick(g, pid, creatures, "Mind Maggots: discard a creature card")
		creatures.erase(pick)
		thrown.append(pick)
	if thrown.is_empty(): return
	g.discard_cards(pid, thrown)
	var discarded := 0
	for card in thrown:
		if card.zone != Mtg.Zone.HAND: discarded += 1
	if discarded > 0 and F._same_trigger_source(g, s):
		g.add_counters(s, "+1/+1", 2 * discarded)


# ------------------------------------------------------------- Pandemonium --

## "That creature's controller" — named by the event, as it entered.
static func _entering_controller(_g: MtgGame, _s: CardInstance, e: GameEvent) -> int:
	return int(e.data.get("controller", -1))

static func _entrant_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var i: CardInstance = e.data.get("instance")
	if i != null:
		ctx["entrant"] = i.id
		ctx["entrant_stamp"] = i.layer_timestamp
	return ctx

## The chooser's preference ([method MtgGame.ranking_chooser]). The
## entering creature is the ranked trigger's event ([method
## MtgGame.ranking_event], public — it is on the stack), so its power is
## known: an opposing player it kills comes first; then the opposing
## creature its damage kills that is worth more than the points to the
## face (power + toughness + mana value against one and a half per point);
## then the opposing face; then the opposing creatures it does not kill;
## the chooser's own creatures, and the chooser's own face last. Without
## an event the damage that always lands — the opposing player — leads,
## then the opposing creature with the least toughness left.
static func _pandemonium_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var me := g.ranking_chooser()
	if me < 0: me = g.controller_acting_for(s)
	var power := _ranked_power(g)
	return _pandemonium_value(g, me, a, power) > _pandemonium_value(g, me, b, power)

## The entering creature's power, or -1 when no ranked event names one.
static func _ranked_power(g: MtgGame) -> int:
	var e := g.ranking_event()
	var i: CardInstance = e.data.get("instance") if e != null else null
	return i.cur_power if i != null else -1

static func _pandemonium_value(g: MtgGame, me: int, ref: TargetRef, power := -1) -> float:
	if ref.is_player:
		if ref.player_id == me: return -3000.0
		if power < 0: return 3000.0
		if power >= g.players[ref.player_id].life: return 9000.0
		return 2000.0 + 1.5 * float(power)
	var i := g.find_instance(ref.instance_id)
	if i == null: return -5000.0
	var left := float(i.cur_toughness - i.damage)
	if i.controller_id == me: return -1000.0 - left
	if power < 0: return 2000.0 - left
	if float(power) >= left:
		return 2000.0 + float(maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0) + i.data.cost.mana_value())
	return 1000.0 - left

## The creature, if it is still the object that entered; otherwise its last
## known power (CR 608.2h). "That creature's controller" answers the "may"
## AS THIS RESOLVES (CR 608.2): a creature that changed hands since it
## entered is its new controller's (bug pass 2026-10-06); one that has left
## answers through the controller it entered under. The hint deals it to
## anything but the answerer's own side.
static func _pandemonium(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var creature: CardInstance = e.data.get("instance")
	var chooser := int(e.data.get("controller", -1))
	var targets := g.current_targets()
	if creature == null or targets.is_empty(): return
	var ctx := g.trigger_context(s)
	var same := creature.zone == Mtg.Zone.BATTLEFIELD and creature.layer_timestamp == int(ctx.get("entrant_stamp", -1))
	if same: chooser = creature.controller_id
	if chooser < 0 or chooser >= g.players.size(): return
	var power := creature.cur_power if same else creature.last_power
	if same and not creature.is_creature(): power = 0   # no longer a creature: no power (CR 208.3)
	if power <= 0: return
	var target: TargetRef = targets[0]
	var hint := target.player_id != chooser if target.is_player else true
	if not target.is_player:
		var victim := g.find_instance(target.instance_id)
		hint = victim != null and victim.controller_id != chooser
	var what := g.players[target.player_id].player_name if target.is_player else g.find_instance(target.instance_id).data.card_name
	if not g.agents[chooser].choose_yes_no(g, chooser,
			"Pandemonium: have %s deal %d damage to %s?" % [creature.data.card_name, power, what], hint):
		return
	g.deal_damage(creature, target, power)


# ---------------------------------------------------------------- Pit Spawn --

static func _damages_a_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if e.data.get("source") != s or int(e.data.get("amount", 0)) <= 0: return false
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and (hit.is_creature() if hit.zone == Mtg.Zone.BATTLEFIELD \
		else (hit.last_types & Mtg.CardType.CREATURE) != 0)

static func _victim_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var hit: CardInstance = e.data.get("to_instance")
	if hit != null:
		ctx["hit"] = hit.id
		ctx["hit_stamp"] = hit.layer_timestamp
	return ctx

## "Exile that creature" — the damaged object, if it is still there (one
## that died of the damage is already in the graveyard: nothing happens).
static func _pit_spawn(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var hit := g.find_instance(int(ctx.get("hit", -1)))
	if g.is_present(hit) and hit.layer_timestamp == int(ctx.get("hit_stamp", -2)):
		g.exile_permanent(hit)


# --------------------------------------------------------------- Spellshock --

static func _spellshock(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0 and who < g.players.size():
		g.deal_damage(s, TargetRef.player(who), 2)


# -------------------------------------------------------------- Welkin Hawk --

## "You may search": the hint asks the seat's own decklist whether another
## Welkin Hawk is unaccounted for (no decklist: search). The found card is
## revealed; "then shuffle" follows the search either way.
static func _welkin_hawk(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if g.players[pid].library.is_empty(): return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Welkin Hawk: search your library for a card named Welkin Hawk?", _hawks_unseen(g, pid)):
		return
	g.search_library(pid, _named_welkin_hawk, "Search your library for a card named Welkin Hawk",
		false, true, "Welkin Hawk reveals")

static func _named_welkin_hawk(i: CardInstance) -> bool:
	return i.data.card_name == "Welkin Hawk"

static func _hawks_unseen(g: MtgGame, pid: int) -> bool:
	var p := g.players[pid]
	if p.deck_names.is_empty(): return true
	var left := 0
	for card_name in p.deck_names:
		if card_name == "Welkin Hawk": left += 1
	var seen: Array = p.hand.duplicate()
	for player in g.players:
		for zone in [player.battlefield, player.graveyard, player.exile, player.ante]:
			seen.append_array(zone)
	for inst in seen:
		if not inst.face_down and not inst.is_token and inst.owner_id == pid \
				and inst.data.card_name == "Welkin Hawk":
			left -= 1
	return left > 0


# ----------------------------------------------------------- Zealots en-Dal --

static func _all_nonland_white(g: MtgGame, pid: int) -> bool:
	for i in g.players[pid].battlefield:
		if g.is_present(i) and not i.is_land() and not i.has_color(Mtg.ManaColor.W):
			return false
	return true

static func _zealots_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _all_nonland_white(g, s.controller_id)

## The intervening "if", rechecked on resolution (CR 603.4).
static func _zealots(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if _all_nonland_white(g, pid):
		g.adjust_life(pid, 1)

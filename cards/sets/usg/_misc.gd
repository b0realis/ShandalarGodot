extends RefCounted
## Urza's Saga (_misc, Pack 10). Everything else: global effects and one-off
## rules — the cards each built on one small engine package.
##
## - "Put into a graveyard from anywhere" (Pack 10 E4,
##   Mtg.EventType.CARD_PUT_INTO_GRAVEYARD — one event per CARD, never a
##   token, never a card a graveyard replacement exiled instead):
##   Planar Void exiles "another card" only while it is still the graveyard
##   object it fired for (its `graveyard_entry`, CR 400.7); Energy Field's
##   sacrifice hears a card into its controller's graveyard and sacrifices
##   only the Field that triggered (it is off the battlefield as it arrives
##   itself, CR 603.6c, so it never hears itself); Serra Avatar's shuffle is
##   a GRAVEYARD trigger of the Avatar itself — from the hand, the library,
##   the battlefield or the stack — and acts on the same graveyard object.
## - Serra Avatar's size: a characteristic-defining static reading its
##   controller's life (its owner's off the battlefield, CR 604.3), flagged
##   `reading_life()` (Pack 10 E3) so a life change is judged at the same
##   state-based check (CR 704.5f-g).
## - Energy Field's prevention: a static damage replacement on its
##   controller, the source's controller read live (CR 609.7b).
## - Gilded Drake (Pack 10 E4, "This ability still resolves if its target
##   becomes illegal" — TriggeredAbility.still_resolves): the exchange is
##   all or nothing (CR 701.10c); when there is none, "sacrifice this
##   creature" is the trigger CONTROLLER's instruction, so it is carried out
##   only on the same Drake (CR 400.7) and only while that player controls
##   it (CR 701.17a) — a Drake given away in response stays where it is.
## - Yawgmoth's Will (Pack 10 E5, MtgGame.grant_zone_play): lands and spells
##   from your graveyard this turn — a land as the land drop, a spell with
##   its printed timing and costs — and a floating "exile it instead" for
##   every card headed for your graveyard (Forbidden Crypt's field, CR
##   614.1), recalculated before the Will itself finishes, so the Will is
##   exiled too; it outlasts the cleanup discard (CR 514.1, 514.2).
## - Temporal Aperture (Pack 10 E5): shuffle, reveal the top card to both
##   players, then a LIBRARY permission naming that card, free ("without
##   paying its mana cost": its own payment row, X = 0, CR 118.9, 107.3b),
##   lands as the land drop, and a floating "play with the top card
##   revealed" naming THAT card (MtgPlayer.top_revealed_card_id, judged
##   live by MtgGame.revealed_top_card, so the card under it is never
##   shown) — both only "for as long as that card remains on top": it is
##   the top card and the library's top has not moved since
##   (MtgPlayer.library_top_epoch) — a card drawn, milled or covered and
##   back on top did not REMAIN there, and even a shuffle that leaves it on
##   top ends it, as Forge's does.
## - Show and Tell (Pack 10 E10, MtgGame.put_onto_battlefield_together):
##   each player, the active player first (CR 101.4), may choose an
##   artifact, creature, enchantment or land card in their hand — an Aura
##   only when something on the battlefield could hold it (CR 303.4f-g) —
##   and the choices stay hidden until both players have chosen (CR
##   101.4a), then are revealed together; then the chosen cards arrive
##   TOGETHER (each "whenever another ... enters" sees the other), under
##   their owners' control. Not cast, not a land drop.
## - Serra's Hymn (Pack 10 E7, EffectBase.divided_by): the verse upkeep of
##   the Saga verse enchantments (usg/_enchantments.gd `verse`), and "prevent
##   the next X damage ... divided as you choose" with X read from its verse
##   counters as the ability is announced — before the sacrifice cost —
##   and locked on the targets' shares (CR 601.2c-d, 602.2b, 608.2h).
## - Thran Turbine (Pack 10 E8): "you may add {C}{C}" at each of your
##   upkeeps — an ordinary trigger on the stack (CR 605.1b does not make it a
##   mana ability), which still resolves with the Turbine gone (CR 113.7a)
##   — as mana no spell may spend (ManaPool.NOT_SPELL, CR
##   106.6); it burns like any other under the mana-burn rule, so the
##   default answer is yes only when it cannot burn or the seat has an
##   activated ability with a mana cost to spend it on (its own board).
## - Contamination (Pack 10 E8): every land tapped for mana makes exactly
##   one {B} instead of any other type and amount
##   (ManaAbility.replace_land_mana, CR 106.6, 614.1a); its upkeep asks a
##   creature of its controller, else it is sacrificed (the "unless" is a
##   cost asked on resolution, Endless Wurm's shape).
## tests/cards/test_pack_10_B13_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")
const UE := preload("res://cards/sets/usg/_enchantments.gd")
const UC := preload("res://cards/sets/usg/_creatures.gd")

const GRAVE := Mtg.EventType.CARD_PUT_INTO_GRAVEYARD
const ETB := Mtg.EventType.ENTERS_BATTLEFIELD


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Serra Avatar":
			c.static_ability(StaticAbility.new(_life_size,
				"Serra Avatar's power and toughness are each equal to your life total.") \
				.setting_base_pt().reading_life())
			c.characteristic_definition = _life_size
			c.with_graveyard_trigger(TriggeredAbility.new(GRAVE, _avatar_home,
				"When Serra Avatar is put into a graveyard from anywhere, shuffle it into its owner's library.",
				_self_arrived))
		"Energy Field":
			c.static_ability(StaticAbility.new(_energy_field,
				"Prevent all damage that would be dealt to you by sources you don't control."))
			c.triggered(TriggeredAbility.new(GRAVE, _field_sacrifice,
				"When a card is put into your graveyard from anywhere, sacrifice this enchantment.",
				_into_your_graveyard))
		"Gilded Drake":
			c.triggered(TriggeredAbility.new(ETB, _drake_exchange,
				"When this creature enters, exchange control of this creature and up to one target creature an opponent controls. If you don't or can't make an exchange, sacrifice this creature. This ability still resolves if its target becomes illegal.",
				F._self_enter) \
				.targeting_up_to(TargetSpec.creature("target creature an opponent controls") \
					.with_source_filter(_an_opponents), 1, _best_first,
					"Select a creature an opponent controls.") \
				.still_resolves())
		"Planar Void":
			c.triggered(TriggeredAbility.new(GRAVE, _void_exile,
				"Whenever another card is put into a graveyard from anywhere, exile that card.",
				_another_card))
		"Yawgmoth's Will":
			c.spell(F.Action.new(_will,
				"until end of turn, you may play lands and cast spells from your graveyard; cards put into your graveyard this turn are exiled instead",
				null, true))
		"Temporal Aperture":
			c.activated(ActivatedAbility.new("{5}", true, [F.Action.new(_aperture,
				"shuffle your library and reveal the top card; you may play it this turn without paying its mana cost while it remains on top",
				null, true)],
				"{5}, {T}: Shuffle your library, then reveal the top card. Until end of turn, for as long as that card remains on top of your library, play with the top card of your library revealed and you may play that card without paying its mana cost. (If it has X in its mana cost, X is 0.)"))
		"Serra's Hymn":
			UE.verse(c)
			var prevent := PreventDamageEffect.new(0).any_target()
			prevent.divided_by(EffectBase.source_counters("verse"))
			c.activated(ActivatedAbility.new("", false, [prevent],
				"Sacrifice this enchantment: Prevent the next X damage that would be dealt this turn to any number of targets, divided as you choose, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		"Thran Turbine":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _turbine,
				"At the beginning of your upkeep, you may add {C}{C}. This mana can't be spent to cast spells.",
				F._your_upkeep))
		"Contamination":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _contamination_upkeep,
				"At the beginning of your upkeep, sacrifice this enchantment unless you sacrifice a creature.",
				F._your_upkeep))
			c.static_ability(StaticAbility.new(_contaminate,
				"If a land is tapped for mana, it produces {B} instead of any other type and amount."))
		"Show and Tell":
			c.spell(F.Action.new(_show_and_tell,
				"each player may put an artifact, creature, enchantment, or land card from their hand onto the battlefield",
				null, true))
		_: return false
	return true


# ------------------------------------------------------------ Serra Avatar --

## Power and toughness = the life of "you": its controller on the
## battlefield or the stack, its owner anywhere else (CR 604.3).
static func _life_size(g: MtgGame, s: CardInstance) -> void:
	var n := UC.you(g, s).life
	s.cur_power = n
	s.cur_toughness = n


static func _self_arrived(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s


## Shuffle it into its owner's library — only the graveyard object that
## arrived (CR 400.7): one that left in response is not followed.
static func _avatar_home(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(e.data.get("graveyard_entry", -1)):
		return
	g.return_from_graveyard_to_library_top(s)
	g.shuffle_library(s.owner_id)


# ------------------------------------------------------------ Energy Field --

static func _energy_field(g: MtgGame, s: CardInstance) -> void:
	g.add_static_damage_effect(s, {"kind": &"prevent", "desc": "Energy Field",
		"victims": [{"player": s.controller_id}],
		"source_filter": _not_controlled_by.bind(s.controller_id)})


static func _not_controlled_by(_g: MtgGame, source: CardInstance, pid: int) -> bool:
	return source != null and source.controller_id != pid


static func _into_your_graveyard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("owner", -1)) == s.controller_id


## "Sacrifice this enchantment": the Field that triggered, still here, by
## the player who controls it (the trigger's controller).
static func _field_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and s.controller_id == g.controller_acting_for(s):
		g.sacrifice_permanent(s)


# ------------------------------------------------------------ Gilded Drake --

static func _an_opponents(g: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	if source == null:
		return true
	return inst.controller_id != g.controller_acting_for(source)


## The opponent's best creature first: the most power plus toughness.
static func _best_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	return va > vb if va != vb else ia.id < ib.id


static func _drake_exchange(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	# A Drake that left (and maybe came back) is not this object any more:
	# there is nothing to exchange and nothing to sacrifice (CR 400.7).
	if not F._same_trigger_source(g, s):
		return
	var you := g.controller_acting_for(s)
	var ref := g.current_trigger_target(0)   # null: none chosen, or illegal now
	var victim: CardInstance = g.find_instance(ref.instance_id) if ref != null else null
	if victim != null and s.controller_id == you and g.exchange_control(s, victim):
		return
	# "If you don't or can't make an exchange, sacrifice this creature" —
	# yours to sacrifice only while you control it (CR 701.17a).
	if g.is_present(s) and s.controller_id == you:
		g.sacrifice_permanent(s)


# ------------------------------------------------------------- Planar Void --

static func _another_card(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") != s


static func _void_exile(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var card: CardInstance = e.data.get("instance")
	if card != null and card.zone == Mtg.Zone.GRAVEYARD \
			and card.graveyard_entry == int(e.data.get("graveyard_entry", -1)):
		g.exile_from_graveyard(card)


# --------------------------------------------------------- Yawgmoth's Will --

static func _will(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.grant_zone_play(pid, {"zone": Mtg.Zone.GRAVEYARD, "lands": true, "spells": true,
		"top_only": false, "source": s, "desc": "lands and spells from their graveyard"})
	g.continuous.add_floating_static(s, StaticAbility.new(_will_exile.bind(pid),
		"If a card would be put into your graveyard from anywhere this turn, exile that card instead."))
	# Now, before the Will itself is put into its owner's graveyard.
	g.recalculate()


static func _will_exile(g: MtgGame, _s: CardInstance, pid: int) -> void:
	g.players[pid].graveyard_becomes_exile = true


# ------------------------------------------------------- Temporal Aperture --

static func _aperture(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.shuffle_library(pid)
	var library := g.players[pid].library
	if library.is_empty():
		return
	var top: CardInstance = library.back()
	g.reveal_information(-1, "Temporal Aperture — the top card of %s's library" % g.players[pid].player_name,
		[top.data.card_name])
	g.log_line("%s reveals %s from the top of their library" % [g.players[pid].player_name,
		top.data.card_name], top)
	var epoch := g.players[pid].library_top_epoch
	var still := _still_on_top.bind(pid, top.id, epoch)
	g.grant_zone_play(pid, {"zone": Mtg.Zone.LIBRARY, "card": top, "lands": true,
		"spells": true, "free": true, "while": still, "source": s,
		"desc": "%s from the top of their library without paying its mana cost" % top.data.card_name})
	g.continuous.add_floating_static(s, StaticAbility.new(_reveal_top.bind(pid, top.id, epoch, still),
		"Play with the top card of your library revealed."))
	g.recalculate()


## "For as long as that card remains on top of your library": it is the top
## card now and the top of the library has not moved since
## ([member MtgPlayer.library_top_epoch]) — a card drawn, milled or covered
## and then back on top did not REMAIN there (CR 400.7; Forge's
## StillTopCheck ends for good), and a shuffle that happens to leave it on
## top ends it too (Forge's ShuffleCheck, temporal_aperture.txt). The
## effect ends at cleanup.
static func _still_on_top(g: MtgGame, _card: CardInstance, pid: int, card_id: int,
		epoch: int) -> bool:
	var p := g.players[pid]
	return not p.library.is_empty() and p.library.back().id == card_id \
		and p.library_top_epoch == epoch


## "Play with the top card of your library revealed": THAT card only, named
## with the epoch it was revealed at — MtgGame.revealed_top_card judges it
## live, so a draw inside a resolution never reveals the card under it.
static func _reveal_top(g: MtgGame, _s: CardInstance, pid: int, card_id: int, epoch: int,
		still: Callable) -> void:
	if bool(still.call(g, null)):
		g.players[pid].top_revealed_card_id = card_id
		g.players[pid].top_revealed_epoch = epoch


# ----------------------------------------------------------- Show and Tell --

const SHOWN_TYPES := Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE \
	| Mtg.CardType.ENCHANTMENT | Mtg.CardType.LAND


static func _show_and_tell(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	# Each player chooses, the active player first (CR 101.4), and the
	# choices stay hidden until both have chosen (CR 101.4a: cards chosen
	# from a hidden zone may stay face down until every player has) — no
	# reveal and no log line before the second choice, so neither the
	# opponent's question nor its answer can know the first (bug pass
	# 0.60.19). Then both are revealed and arrive together.
	var entries: Array = []
	for pid in [g.active_player, g.opponent_of(g.active_player)]:
		if g.players[pid].has_lost:
			continue
		var pick := _shown_card(g, pid)
		if pick != null:
			entries.append({"instance": pick, "controller": pid})
	for entry in entries:
		var pick: CardInstance = entry["instance"]
		var who := g.players[int(entry["controller"])].player_name
		g.reveal_information(-1, "Show and Tell — %s's choice" % who, [pick.data.card_name])
		g.log_line("%s chooses %s for Show and Tell" % [who, pick.data.card_name], pick)
	g.put_onto_battlefield_together(entries)


## [param pid]'s choice: "may" (yes / no), then which card — the biggest
## first (the default answer) among the artifact, creature, enchantment
## and land cards of their hand, an Aura only with a host to go on.
static func _shown_card(g: MtgGame, pid: int) -> CardInstance:
	var candidates: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if (card.cur_types & SHOWN_TYPES) == 0:
			continue
		if card.data.is_aura() and g.aura_entry_hosts(card, pid).is_empty():
			continue   # CR 303.4g: nothing to enchant, it would stay in the hand
		candidates.append(card)
	if candidates.is_empty():
		return null
	if not g.agents[pid].choose_yes_no(g, pid,
			"Put an artifact, creature, enchantment, or land card onto the battlefield with Show and Tell?", true):
		return null
	candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var va := a.data.cost.mana_value()
		var vb := b.data.cost.mana_value()
		return va > vb if va != vb else a.id < b.id)
	var pick := g.agents[pid].choose_card(g, pid, candidates,
		"Choose a card to put onto the battlefield", false, false, true)
	if pick == null or not candidates.has(pick):
		pick = candidates[0]
	return pick


# ------------------------------------------------------------ Thran Turbine --

## The trigger is independent of its source once it is on the stack (CR
## 113.7a): a Turbine gone in response still adds the mana, to the
## trigger's controller (Forge's resolves the same; bug pass 0.60.19).
static func _turbine(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := g.controller_acting_for(s)
	if g.agents[pid].choose_yes_no(g, pid,
			"Thran Turbine: add {C}{C}? (It can't be spent to cast spells.)", _turbine_hint(g, pid)):
		g.players[pid].mana_pool.add_restricted(Mtg.ManaColor.C, 2, ManaPool.NOT_SPELL)
		g.log_line("%s adds {C}{C} (not for spells)" % g.players[pid].player_name, s)


## Yes when the mana cannot burn, or when [param pid] controls a permanent
## with a non-mana activated ability that costs mana — its own board only.
static func _turbine_hint(g: MtgGame, pid: int) -> bool:
	if not g.rules.mana_burn:
		return true
	for inst in g.players[pid].battlefield:
		for ability in inst.cur_activated_abilities:
			if ability.cost.mana_value() > 0:
				return true
	return false


# ------------------------------------------------------------ Contamination --

static func _contaminate(g: MtgGame, _s: CardInstance) -> void:
	for land in g.all_battlefield():
		if land.is_land():
			ManaAbility.replace_land_mana(land, Mtg.ManaColor.B, 1)


## "Sacrifice this enchantment unless you sacrifice a creature": the object
## that triggered, by the player who controls it. The hint keeps the
## enchantment while a creature can pay.
static func _contamination_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := g.controller_acting_for(s)
	if not F._same_trigger_source(g, s) or s.controller_id != pid:
		return
	if g.unless_objects_paid(pid, s, [OC.sacrificing("creature", _creature)],
			"Contamination: sacrifice a creature? (otherwise sacrifice Contamination)", true):
		return
	g.sacrifice_permanent(s)


static func _creature(i: CardInstance) -> bool:
	return i.is_creature()

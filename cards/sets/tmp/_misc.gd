extends RefCounted
## Tempest (_misc, Pack 9). Everything else: global effects and one-off rules.
##
## - Humility is AS PRINTED (owner ruling 2026-10-06), on Pack 9 E5's two
##   ready-made statics: "lose all abilities" is a layer-6 effect at
##   Humility's own timestamp (an ability granted EARLIER — an Aura already
##   attached, a Jump cast before it — goes, one granted LATER stays; a
##   creature's own abilities never survive, CR 613.8a), and the 1/1 is a
##   layer-7b set at the same timestamp (a later "becomes 2/2" wins, an
##   earlier one loses, CR 613.7). Pumps, anthems and counters still add on
##   top (7c-7d). A trigger granted after Humility fires, and every pool
##   grant declares its layer (Pack 9 engine follow-up, 2026-10-06).
## - Nature's Revolt prints its two layers as two statics — the type change
##   (layer 4) and the 2/2 (layer 7b, at its own timestamp) — so Humility and
##   the Revolt settle the lands' size by timestamp (CR 613.7), and a land
##   under Humility loses its mana abilities (it is a creature).
## - Ertai's Meddling and Scragnoth are Pack 9 E6's: exiling a spell is not
##   countering it (CR 701.5a), so the Meddling works on a Scragnoth; "X
##   can't be 0" is refused at announcement.
## - Static Orb and Rootwater Matriarch are Pack 9 E8's: the "permanent"
##   untap cap, and control that lasts while the VICTIM is enchanted
##   (CR 611.2b), whatever becomes of the Matriarch.
## - Duplicity links the cards it exiles to THIS object, per exile visit
##   (Gustha's Scepter's shape, all/_links.gd: [id, exile_entry] rows, CR
##   400.7, 607.2a); "when you lose control" is a control change or leaving
##   the battlefield. The face-down cards are seen by nobody; the "may"
##   hint counts them against the hand, never names them (fair play).
## - Living Death: every player exiles at once, then every creature is
##   sacrificed in one simultaneous event (CR 704.3), then each player's
##   exiled cards return under their control.
## - Hand to Hand's two bans read the step live: the whole combat phase
##   (beginning of combat through end of combat, CR 506.1).
## tests/cards/test_pack_9_B8_misc.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")
const OC := preload("res://engine/additional_object_costs.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Broken Fall":
			c.activated(ActivatedAbility.new("", false, [RegenerateEffect.new().target_creature()],
				"Return this enchantment to its owner's hand: Regenerate target creature.").with_return_cost())
		"Choke":
			c.static_ability(StaticAbility.new(_choke,
				"Islands don't untap during their controllers' untap steps."))
		"Dread of Night":
			c.static_ability(StaticAbility.new(_dread, "White creatures get -1/-1."))
		"Duplicity":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _duplicity_enter,
				"When this enchantment enters, exile the top five cards of your library face down.",
				F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _duplicity_upkeep,
				"At the beginning of your upkeep, you may exile all cards from your hand face down. If you do, put all other cards you own exiled with this enchantment into your hand.",
				F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _duplicity_discard,
				"At the beginning of your end step, discard a card.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.CONTROL_CHANGED, _duplicity_lost,
				"When you lose control of this enchantment, put all cards exiled with this enchantment into their owner's graveyard.",
				F._self_enter).also_when(Mtg.EventType.LEAVES_BATTLEFIELD).capturing(_duplicity_links))
		"Earthcraft":
			c.activated(ActivatedAbility.new("", false,
				[UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target basic land", _basic_land))],
				"Tap an untapped creature you control: Untap target basic land.") \
				.with_object_cost(OC.tapping("an untapped creature you control", _creature)))
		"Ertai's Meddling":
			c.spell(MeddlingEffect.new())
			c.announcement_condition = _x_not_zero
		"Fevered Convulsions":
			c.activated(ActivatedAbility.new("{2}{B}{B}", false,
				[CounterMarkerEffect.new("-1/-1", 1, TargetSpec.creature())],
				"{2}{B}{B}: Put a -1/-1 counter on target creature."))
		"Furnace of Rath":
			var furnace := StaticAbility.new(_furnace,
				"If a source would deal damage to a permanent or player, it deals double that damage to that permanent or player instead.")
			# The fair AI's shape (the Pack 9 bug pass, h6-6;
			# engine/ai/tempest_spells.gd `doubler_choice`): every source's
			# damage, both players', doubled.
			furnace.set_meta(&"ai_role", &"damage_doubler")
			furnace.set_meta(&"ai_parameters", {"factor": 2})
			c.static_ability(furnace)
		"Hand to Hand":
			c.bans_playing(_no_instants_in_combat)
			c.bans_activations(_no_abilities_in_combat)
		"Hanna's Custody":
			c.static_ability(StaticAbility.new(_custody,
				"All artifacts have shroud.").changing_abilities())
		"Humility":
			c.static_ability(StaticAbility.removing_all_abilities(_any_creature,
				"All creatures lose all abilities."))
			c.static_ability(StaticAbility.base_pt_for(_any_creature, 1, 1,
				"All creatures have base power and toughness 1/1."))
		"Light of Day":
			c.static_ability(StaticAbility.new(_light_of_day, "Black creatures can't attack or block."))
		"Living Death":
			c.spell(LivingDeath.new())
		"Nature's Revolt":
			c.static_ability(StaticAbility.new(_revolt_type,
				"All lands are 2/2 creatures that are still lands.").changing_types())
			c.static_ability(StaticAbility.new(_revolt_size,
				"All lands are 2/2 (their base power and toughness).").setting_base_pt())
		"Root Maze":
			c.taps_permanents_entering(_root_maze)
		"Rootwater Matriarch":
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_matriarch, "gain control of target creature for as long as that creature is enchanted",
					TargetSpec.creature()).with_ai_role(&"steal_while_enchanted")],
				"{T}: Gain control of target creature for as long as that creature is enchanted."))
		"Scragnoth":
			c.with_cant_be_countered()
		"Static Orb":
			c.static_ability(StaticAbility.new(_static_orb,
				"As long as this artifact is untapped, players can't untap more than two permanents during their untap steps."))
		_: return false
	return true


# ============================================================ predicates

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _anything(_i: CardInstance) -> bool: return true

static func _basic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0

static func _any_creature(_g: MtgGame, _s: CardInstance, i: CardInstance) -> bool:
	return i.is_creature()


# ------------------------------------------------------------------- Choke --

static func _choke(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("island"):
			i.cur_skips_untap = true


# ---------------------------------------------------------- Dread of Night --

static func _dread(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.W) != 0:
			i.cur_power -= 1
			i.cur_toughness -= 1


# --------------------------------------------------------------- Duplicity --

const LINK := "duplicity"

## The linked cards still in exile on the same visit (CR 400.7).
static func _linked(g: MtgGame, rows: Array) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for row in rows:
		var i := g.find_instance(int(row[0]))
		if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == int(row[1]):
			cards.append(i)
	return cards


## The rows of THIS Duplicity, while the trigger's source is still it.
static func _rows(g: MtgGame, s: CardInstance) -> Array:
	if not F._same_trigger_source(g, s): return []
	return (s.memory.get(LINK, []) as Array).duplicate(true)


static func _link(g: MtgGame, s: CardInstance, rows: Array) -> void:
	if not F._same_trigger_source(g, s): return
	g._rec(s, &"memory")
	s.memory[LINK] = rows


static func _duplicity_enter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := MC.pid_of(g, s)
	var rows := _rows(g, s)
	for _k in 5:
		var card := g.exile_top_of_library(pid, true, -1)
		if card == null: break
		rows.append([card.id, card.exile_entry])
	_link(g, s, rows)


## "You may exile all cards from your hand face down. If you do, put all
## OTHER cards you own exiled with this enchantment into your hand" — the
## others are the ones linked before this hand went (an empty hand may be
## "exiled" too). The hint compares counts only: nobody may look at the
## face-down pile.
static func _duplicity_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := MC.pid_of(g, s)
	var rows := _rows(g, s)
	var mine: Array[CardInstance] = []
	for card in _linked(g, rows):
		if card.owner_id == pid: mine.append(card)
	var hand: Array[CardInstance] = g.players[pid].hand.duplicate()
	var hint := not mine.is_empty() and mine.size() >= hand.size()
	if not g.agents[pid].choose_yes_no(g, pid,
			"Duplicity: exile your hand (%d) face down and take the %d card(s) you own exiled with it?" % [
				hand.size(), mine.size()], hint):
		return
	var kept: Array = []
	for row in rows:
		var card := g.find_instance(int(row[0]))
		if card != null and not mine.has(card): kept.append(row)
	for card in hand:
		g.exile_from_hand(card, true, -1)
		if card.zone == Mtg.Zone.EXILE: kept.append([card.id, card.exile_entry])
	for card in mine:
		g.return_from_exile_to_hand(card, false)
	_link(g, s, kept)


static func _duplicity_discard(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := MC.pid_of(g, s)
	if g.players[pid].hand.is_empty(): return
	g.discard_cards(pid, g.agents[pid].choose_discard(g, pid, 1))


## The links as the ability triggers: the departing object's memory
## snapshot when it leaves, its live memory on a control change.
static func _duplicity_links(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var memory: Dictionary = e.data.get("memory", s.memory)
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"links": (memory.get(LINK, []) as Array).duplicate(true)}


static func _duplicity_lost(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for card in _linked(g, g.trigger_context(s).get("links", [])):
		g.return_from_exile_to_graveyard(card)


# ---------------------------------------------------------- Ertai's Meddling --

static func _x_not_zero(_g: MtgGame, _pid: int, _card: CardInstance, x: int, _t: Array) -> String:
	return "" if x > 0 else "X can't be 0"


## "Target spell's controller exiles it with X delay counters on it" — not a
## counter (CR 701.5a); the upkeep countdown and the return as a copy of
## the original spell are the engine's (MtgGame.delay_spell, Pack 9 E6).
class MeddlingEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell("target spell")
		ai_role = &"delay_spell"
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var spell := g.find_instance(t.instance_id)
		if spell != null and x > 0:
			g.delay_spell(spell, x, s, pid)
	func describe() -> String:
		return "target spell's controller exiles it with X delay counters on it"


# ---------------------------------------------------------- Furnace of Rath --

## A damage MODIFIER on every source and every victim (CR 614.1a); the
## affected player orders it against preventions (CR 616.1). Two Furnaces
## are two replacements: quadruple.
static func _furnace(g: MtgGame, s: CardInstance) -> void:
	g.add_static_damage_effect(s, {"kind": &"modify", "factor": 2,
		"desc": "Furnace of Rath: the damage is doubled"})


# ------------------------------------------------------------- Hand to Hand --

static func _no_instants_in_combat(g: MtgGame, _pid: int, data: CardData) -> bool:
	return Mtg.is_combat_step(g.current_step()) and data.is_type(Mtg.CardType.INSTANT)


static func _no_abilities_in_combat(g: MtgGame, _s: CardInstance, _pid: int,
		_inst: CardInstance, _ability: Variant, is_mana: bool) -> bool:
	return Mtg.is_combat_step(g.current_step()) and not is_mana


# ---------------------------------------------------------- Hanna's Custody --

## Shroud is an ability (layer 6, CR 702.18): granted at the Custody's
## timestamp, so a Humility that entered later removes it from an artifact
## creature, an older one does not.
static func _custody(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_type(Mtg.CardType.ARTIFACT):
			i.cur_shroud = true


# ------------------------------------------------------------- Light of Day --

static func _light_of_day(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.B) != 0:
			i.cur_cant_attack = true
			MC.cant_block(i, _anything)


# ------------------------------------------------------------- Living Death --

## Three instructions, each done by every player at once (APNAP for the
## order of the moves, CR 101.4): exile the creature CARDS in the
## graveyards, sacrifice the creatures on the battlefield in one event,
## then each player puts the cards THEY exiled this way onto the
## battlefield — exactly those objects, on that exile visit (CR 400.7).
## SIMPLIFIED (docs/simplified-cards.md, "Living Death"): the returned
## creatures enter one after another in APNAP order rather than at the
## same instant, so a returned "whenever another creature enters" ability
## (Soul Warden) sees only the creatures that enter after it.
class LivingDeath extends EffectBase:
	func _init() -> void:
		ai_role = &"living_death"
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var order: Array[int] = [g.active_player, g.opponent_of(g.active_player)]
		var exiled := {}
		for p in order:
			var rows: Array = []
			for card in (g.players[p].graveyard as Array).duplicate():
				var inst := card as CardInstance
				if inst == null or not inst.data.is_creature(): continue
				g.exile_from_graveyard(inst)
				if inst.zone == Mtg.Zone.EXILE: rows.append([inst.id, inst.exile_entry])
			exiled[p] = rows
		g.begin_simultaneous()
		for p in order:
			for inst in (g.players[p].battlefield as Array).duplicate():
				if g.is_present(inst) and inst.is_creature() and inst.controller_id == p:
					g.sacrifice_permanent(inst)
		g.end_simultaneous()
		g.begin_simultaneous()
		for p in order:
			for row in exiled[p]:
				var inst := g.find_instance(int(row[0]))
				if inst != null and inst.zone == Mtg.Zone.EXILE and inst.exile_entry == int(row[1]):
					g.return_from_exile_to_play(inst, p)
		g.end_simultaneous()
	func describe() -> String:
		return "each player exiles all creature cards from their graveyard, then sacrifices all creatures they control, then puts all cards they exiled this way onto the battlefield"


# ----------------------------------------------------------- Nature's Revolt --

static func _revolt_type(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land():
			i.cur_types |= Mtg.CardType.CREATURE


static func _revolt_size(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.is_creature():
			i.cur_power = 2
			i.cur_toughness = 2


# ------------------------------------------------------------------ Root Maze --

## A replacement as the permanent arrives (CR 614.1c, Kismet's shape):
## types read live, both players'.
static func _root_maze(_g: MtgGame, _s: CardInstance, entering: CardInstance, _controller: int) -> bool:
	return entering.is_land() or entering.is_type(Mtg.CardType.ARTIFACT)


# ------------------------------------------------------- Rootwater Matriarch --

static func _enchanted(g: MtgGame, victim: CardInstance) -> bool:
	return g.is_enchanted(victim)


## The duration follows the victim (CR 611.2b), not the Matriarch; an
## unenchanted target is a legal one, and nothing happens.
static func _matriarch(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var victim := g.find_instance(t.instance_id)
	if g.is_present(victim):
		g.gain_control_while(victim, pid, _enchanted, s)


# ---------------------------------------------------------------- Static Orb --

## "As long as this artifact is untapped" is the card's own test; under the
## 1997 rules a tapped Orb's static is suspended anyway.
static func _static_orb(g: MtgGame, s: CardInstance) -> void:
	if not s.tapped:
		g.cap_untaps("permanent", 2, s)

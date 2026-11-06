extends RefCounted
## Urza's Legacy (_triggers, Pack 10). Triggered abilities: enters, leaves, dies, upkeep and spell triggers.
##
## Same conventions as the Mirage and Tempest modules
## (cards/sets/mir/_triggers.gd, whose shared helpers this reuses as M;
## cards/sets/mir/_combat.gd's pair helpers as MC):
## - A triggered ability exists apart from its source (CR 603.6 / 608.2h):
##   it resolves even when the source has left, acting for the seat that
##   controlled it (M.pid_of). Only the clauses that name the source itself
##   ("it gets +0/+2", "return this creature") check that the very same
##   object is still there (F._same_trigger_source, CR 400.7).
## - "When this creature dies, return it to its owner's hand" (Shivan
##   Phoenix, Weatherseed Treefolk) is a trigger, not Firestorm Phoenix's
##   replacement: the card's graveyard entry is captured as it triggers
##   (M._dead_context) and the card returns only if it is still that card
##   in that graveyard — exiled from it in response, it stays exiled.
## - "Whenever this creature blocks" hears BECOMES_BLOCKER and "becomes
##   blocked" BECOMES_BLOCKED, once each however many creatures are
##   involved (Giant Badger's lesson, phpr/giant_badger.gd); Gang of Elk
##   counts its blockers as the trigger resolves (Jungle Wurm's shape).
##   "Blocks or becomes blocked by a creature" (Treefolk Mystic) hears
##   BLOCKED, once per pair (MC.pair_trigger), the other creature captured.
## - "Becomes the target of a spell or ability" hears BECAME_TARGET, once
##   per distinct target per stack object (M.targeted_me).
## - "Whenever this creature becomes tapped" hears BECAME_TAPPED — any tap,
##   attacking included, but not entering tapped; the target is chosen as
##   the trigger goes on the stack (CR 603.3d).
## - "At the beginning of the end step" with no "your" is every end step
##   (Viashino Sandstalker's shape, vis/_triggers.gd).
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Sustainer of the Realm":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _self_pump.bind(0, 2),
				"Whenever this creature blocks, it gets +0/+2 until end of turn.", F._self_enter))
		# ---------------------------------------------------------- black
		"Eviscerator":
			# Protection from white is the scaffold's.
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, M.lose_life.bind(5),
				"When this creature enters, you lose 5 life.", F._self_enter))
		"Rank and File":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _rank_and_file,
				"When this creature enters, green creatures get -1/-1 until end of turn.", F._self_enter))
		"Tethered Skirge":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, M.lose_life.bind(1),
				"Whenever this creature becomes the target of a spell or ability, you lose 1 life.", M.targeted_me))
		# ------------------------------------------------------------ red
		"Goblin Medics":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _medics,
				"Whenever this creature becomes tapped, it deals 1 damage to any target.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.ANY), _ping_first))
		"Shivan Phoenix", "Weatherseed Treefolk":
			# Flying / trample are the scaffolds'.
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _return_dead,
				"When this creature dies, return it to its owner's hand.", F._self_enter).capturing(M._dead_context))
		"Viashino Cutthroat", "Viashino Sandscout":
			# Haste is the scaffolds'.
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _go_home,
				"At the beginning of the end step, return this creature to its owner's hand."))
		# ---------------------------------------------------------- green
		"Gang of Elk":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, _elk,
				"Whenever this creature becomes blocked, it gets +2/+2 until end of turn for each creature blocking it.",
				F._self_enter))
		"Treefolk Mystic":
			c.triggered(MC.pair_trigger(MC.EITHER, Callable(), _mystic,
				"Whenever this creature blocks or becomes blocked by a creature, destroy all Auras attached to that creature."))
		_: return false
	return true


# ------------------------------------------------------------- resolution --

## "It gets +P/+T until end of turn" — only the object that triggered.
static func _self_pump(g: MtgGame, s: CardInstance, _e: GameEvent, power: int, toughness: int) -> void:
	if not F._same_trigger_source(g, s):
		return
	g.continuous.add_until_eot_pump(s.id, power, toughness)
	g.recalculate()

## Rank and File: the green creatures as the trigger resolves, both
## players' (CR 611.2c — a green creature arriving later is untouched).
static func _rank_and_file(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	MassPumpEffect.new(-1, -1, "green creatures").with_filter(_green).resolve(g, s, M.pid_of(g, s), null)

static func _green(i: CardInstance) -> bool:
	return (i.cur_colors & Mtg.ManaColor.G) != 0

## Goblin Medics' target order (its seat's default and the AI's pick,
## public facts only): an opposing creature the 1 damage kills, the
## biggest first; then the opposing player; then any other opposing
## creature; the controller's own side last.
static func _ping_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _ping_value(g, s, a) > _ping_value(g, s, b)

static func _ping_value(g: MtgGame, s: CardInstance, ref: TargetRef) -> int:
	var me := g.controller_acting_for(s)
	if ref.is_player:
		return 50 if ref.player_id != me else -1000
	var i := g.find_instance(ref.instance_id)
	if i == null or i.controller_id == me:
		return -500
	if i.cur_toughness - i.damage <= 1:
		return 100 + i.cur_power + i.cur_toughness
	return 10

## Goblin Medics: from the Medics as it last existed if it has left.
static func _medics(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty() or targets[0] == null:
		return
	g.deal_damage(s, targets[0], 1)

static func _return_dead(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.trigger_context(s).get("entry", -1)):
		g.return_from_graveyard_to_hand(s)

static func _go_home(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.return_to_hand(s)

## Gang of Elk: every creature blocking it — its band's blockers (CR
## 702.22h) — counted as the trigger resolves.
static func _elk(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s):
		return
	var n := g.combat.blockers_of_band(g.combat.band_of(s.id)).size()
	if n <= 0:
		return
	g.continuous.add_until_eot_pump(s.id, 2 * n, 2 * n)
	g.recalculate()

## Treefolk Mystic: the Auras attached to the other creature as the
## trigger resolves, destroyed at once.
static func _mystic(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := MC.pair_other_live(g, s)
	if other == null:
		return
	var auras: Array[CardInstance] = []
	for aura_id in other.attachments:
		var aura := g.find_instance(aura_id)
		if g.is_present(aura) and aura.is_aura() and aura.attached_to == other.id:
			auras.append(aura)
	if auras.is_empty():
		return
	g.begin_simultaneous()
	for aura in auras:
		g.destroy(aura)
	g.end_simultaneous()

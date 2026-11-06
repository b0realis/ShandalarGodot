extends RefCounted
## Urza's Legacy (_echo, Pack 10). Echo creatures and permanents (batch B10).
## Echo is EchoAbility (engine/abilities/echo.gd, CR 702.30a); the shared
## helpers and conventions are cards/sets/usg/_echo.gd's (U).
##
## - Karmic Guide returns the creature card under the trigger's controller
##   (CR 603.3a "you"), whether or not the Guide is still there.
## - Raven Familiar LOOKS (private to its controller) at the top three and
##   orders the rest onto the bottom, Impulse's shape with three cards
##   (cards/sets/vis/_spells.gd).
## - Deranged Hermit's "Squirrel creatures get +1/+1" is everyone's
##   Squirrels; letting the Hermit go to echo shrinks them back.
## - Thran Weaponry: "{2}, {T}: All creatures get +2/+2 for as long as this
##   artifact remains tapped." The affected set is FIXED as the ability
##   resolves (CR 611.2c): a creature that arrives later gets nothing. The
##   effect is a floating static (Amber Prison's shape,
##   cards/sets/mir/_artifacts.gd), so it outlives a loss of the
##   Weaponry's own abilities (it is the resolved ability's effect, not a
##   static of the card), and it ends for good the moment the Weaponry
##   untaps, phases out (CR 702.26f) or leaves (CR 611.2b). It works while
##   tapped under the 1997 "tapped artifacts stop working" rule too — it is
##   ABOUT being tapped (StaticAbility.working_while_tapped). "You may
##   choose not to untap" is CardData.with_may_skip_untap.
const U := preload("res://cards/sets/usg/_echo.gd")
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const ETB := Mtg.EventType.ENTERS_BATTLEFIELD
const PATH := "res://cards/sets/ulg/_echo.gd"

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Karmic Guide":         # flying, protection from black (scaffold)
			EchoAbility.attach(c, "{3}{W}{W}")
			c.triggered(TriggeredAbility.new(ETB, _karmic_guide,
				"When this creature enters, return target creature card from your graveyard to the battlefield.",
				F._self_enter).targeting(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
					"target creature card from your graveyard"), _biggest_card_first,
					"Karmic Guide: choose a creature card in your graveyard to return."))
		"Radiant's Dragoons":
			EchoAbility.attach(c, "{3}{W}")
			c.triggered(TriggeredAbility.new(ETB, M._gain_life.bind(5),
				"When this creature enters, you gain 5 life.", F._self_enter))
		# ----------------------------------------------------------- blue
		"Raven Familiar":       # flying (scaffold)
			EchoAbility.attach(c, "{2}{U}")
			c.triggered(TriggeredAbility.new(ETB, _raven_familiar,
				"When this creature enters, look at the top three cards of your library. Put one of them into your hand and the rest on the bottom of your library in any order.",
				F._self_enter))
		# ---------------------------------------------------------- black
		"Bone Shredder":        # flying (scaffold)
			EchoAbility.attach(c, "{2}{B}")
			c.triggered(TriggeredAbility.new(ETB, U.destroy_targets,
				"When this creature enters, destroy target nonartifact, nonblack creature.",
				F._self_enter).targeting(TargetSpec.creature("target nonartifact, nonblack creature",
					_nonartifact_nonblack), U.theirs_first,
					"Bone Shredder: choose a nonartifact, nonblack creature to destroy."))
		# ------------------------------------------------------------ red
		"Avalanche Riders":     # haste (scaffold)
			EchoAbility.attach(c, "{3}{R}")
			c.triggered(TriggeredAbility.new(ETB, U.destroy_targets,
				"When this creature enters, destroy target land.",
				F._self_enter).targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
					_land), U.theirs_first, "Avalanche Riders: choose a land to destroy."))
		"Ghitu Slinger":
			EchoAbility.attach(c, "{2}{R}")
			c.triggered(TriggeredAbility.new(ETB, U.damage_target.bind(2),
				"When this creature enters, it deals 2 damage to any target.",
				F._self_enter).targeting(TargetSpec.any_target(), U.theirs_first,
					"Ghitu Slinger: choose a target for 2 damage."))
		# ---------------------------------------------------------- green
		"Deranged Hermit":
			EchoAbility.attach(c, "{3}{G}{G}")
			c.triggered(TriggeredAbility.new(ETB,
				U.make_tokens.bind(CreateTokenEffect.new("Squirrel", 1, 1, Mtg.ManaColor.G, "squirrel", 4)),
				"When this creature enters, create four 1/1 green Squirrel creature tokens.",
				F._self_enter))
			c.static_ability(StaticAbility.new(_squirrels, "Squirrel creatures get +1/+1."))
		"Multani's Acolyte":
			EchoAbility.attach(c, "{G}{G}")
			c.triggered(TriggeredAbility.new(ETB, U.draw_one,
				"When this creature enters, draw a card.", F._self_enter))
		"Simian Grunts":        # flash (scaffold)
			EchoAbility.attach(c, "{2}{G}")
		"Yavimaya Granger":
			EchoAbility.attach(c, "{2}{G}")
			c.triggered(TriggeredAbility.new(ETB, _granger,
				"When this creature enters, you may search your library for a basic land card, put that card onto the battlefield tapped, then shuffle.",
				F._self_enter))
		# ------------------------------------------------------- artifact
		"Ring of Gix":
			EchoAbility.attach(c, "{3}")
			c.activated(ActivatedAbility.new("{1}", true,
				[TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
					"target artifact, creature, or land", _artifact_creature_or_land))],
				"{1}, {T}: Tap target artifact, creature, or land."))
		"Thran War Machine":
			EchoAbility.attach(c, "{4}")
			c.with_keywords([Mtg.Keyword.MUST_ATTACK])   # Juggernaut's (2ed/juggernaut.gd)
		"Thran Weaponry":
			EchoAbility.attach(c, "{4}")
			c.with_may_skip_untap()
			c.activated(ActivatedAbility.new("{2}", true, [Weaponry.new()],
				"{2}, {T}: All creatures get +2/+2 for as long as this artifact remains tapped."))
		"Ticking Gnomes":
			EchoAbility.attach(c, "{3}")
			# The damage comes from the sacrificed Gnomes as they last
			# existed (CR 608.2h) — Mogg Fanatic's shape.
			c.activated(ActivatedAbility.new("", false, [DamageEffect.new(1).any_target()],
				"Sacrifice this creature: It deals 1 damage to any target.").with_sacrifice_cost())
		"Urza's Blueprints":
			EchoAbility.attach(c, "{6}")
			c.activated(ActivatedAbility.new("", true, [DrawEffect.new(1)], "{T}: Draw a card."))
		_: return false
	return true


static func _land(i: CardInstance) -> bool:
	return i.is_land()

static func _artifact_creature_or_land(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()

## Live types and colors (CR 613): a creature painted black or animated
## into an artifact is judged as it is now.
static func _nonartifact_nonblack(i: CardInstance) -> bool:
	return not i.is_type(Mtg.CardType.ARTIFACT) and (i.cur_colors & Mtg.ManaColor.B) == 0

## The biggest card first (its printed size and cost — a card in a
## graveyard has no live characteristics).
static func _biggest_card_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	if ia == null or ib == null: return ia != null
	var va := ia.data.power + ia.data.toughness + ia.data.cost.mana_value()
	var vb := ib.data.power + ib.data.toughness + ib.data.cost.mana_value()
	return va > vb if va != vb else ia.id < ib.id


# -------------------------------------------------------------- Karmic Guide --

## "Your graveyard", "to the battlefield": under the trigger's controller,
## the very card targeted (the engine has checked it is still a legal
## target — still in that graveyard, CR 608.2b).
static func _karmic_guide(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var t := g.current_trigger_target(0)
	if t == null: return
	var card := g.find_instance(t.instance_id)
	if card == null or card.zone != Mtg.Zone.GRAVEYARD: return
	g.reanimate(card, M.pid_of(g, s))


# ------------------------------------------------------------ Raven Familiar --

static func _raven_familiar(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var library := g.players[pid].library
	var n := mini(3, library.size())
	if n == 0: return
	var seen: Array[CardInstance] = []
	for k in n: seen.append(library[library.size() - 1 - k])
	var names: Array = []
	for card in seen: names.append(card.data.card_name)
	g.reveal_information(pid, "Raven Familiar — the top %d card(s) of your library" % n, names)
	var ranked: Array[CardInstance] = preload("res://cards/sets/mir/_spells.gd").P.best_first(g, seen)
	var keep := g.agents[pid].choose_card(g, pid, ranked, "Raven Familiar: choose a card to put into your hand")
	if keep == null or not ranked.has(keep): keep = ranked[0]
	g.library_card_to_hand(keep)
	seen.erase(keep)
	while not seen.is_empty():
		var next: CardInstance = seen[0] if seen.size() == 1 else g.agents[pid].choose_card(g, pid, seen,
			"Raven Familiar: choose the next card to put on the bottom of your library")
		if next == null or not seen.has(next): next = seen[0]
		g.put_on_bottom_of_library(next)
		seen.erase(next)


# ----------------------------------------------------------- Deranged Hermit --

static func _squirrels(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.has_subtype("squirrel"):
			i.cur_power += 1
			i.cur_toughness += 1


# ---------------------------------------------------------- Yavimaya Granger --

## "You may search": the optional pick (declining is finding nothing),
## Rampant Growth's tapped arrival (cards/sets/mir/_choices.gd) — it enters
## tapped, no "becomes tapped" event (CR 614.1c).
static func _granger(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var cards: Array[CardInstance] = []
	for i in g.players[pid].library:
		if i.data.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0:
			cards.append(i)
	var pick := g.agents[pid].choose_card(g, pid, cards,
		"Yavimaya Granger: search your library for a basic land card", true)
	if pick != null and cards.has(pick):
		g.put_library_card_onto_battlefield(pick, pid, true)
	g.shuffle_library(pid)


# ------------------------------------------------------------ Thran Weaponry --

class Weaponry extends EffectBase:
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var stamp := int(g.cost_paid("_source_timestamp", s.layer_timestamp))
		var untaps := int(g.cost_paid("_source_untap_sequence", s.untap_sequence))
		# The duration may already be over (untapped in response): then
		# the effect does nothing at all (CR 611.2b).
		if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped \
				or s.untap_sequence != untaps:
			return
		# CR 611.2c: WHICH creatures get +2/+2 is decided now, once.
		var held: Array = []
		var mine := -1
		for i in g.all_battlefield():
			if not i.is_creature(): continue
			held.append([i.id, i.layer_timestamp])
			if mine < 0 and i.controller_id == s.controller_id: mine = i.id
		var module: GDScript = load(PATH)
		g.continuous.add_floating_static(s, StaticAbility.new(
			module._weaponry_bonus.bind(held, stamp, untaps),
			"All creatures get +2/+2 for as long as Thran Weaponry remains tapped.").working_while_tapped(),
			ContinuousEffects.Duration.INDEFINITE)
		# What the untap step's "you may choose not to untap" heuristic reads
		# (MtgGame._is_sustaining): it holds one of its controller's own.
		g._rec(s, &"memory")
		if mine >= 0:
			s.memory["holding"] = mine
			s.memory["weaponry_untaps"] = untaps
		g.log_line("All creatures get +2/+2 for as long as %s remains tapped" % s.data.card_name, s)
		g.recalculate()
	func describe() -> String:
		return "all creatures get +2/+2 for as long as this artifact remains tapped"


static func _weaponry_bonus(g: MtgGame, s: CardInstance, held: Array, stamp: int, untaps: int) -> void:
	if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped or s.untap_sequence != untaps:
		# Over for good (CR 611.2b): the heuristic's mark goes with it — only
		# this activation's, never a later one's.
		if s.zone == Mtg.Zone.BATTLEFIELD and int(s.memory.get("weaponry_untaps", -1)) == untaps:
			if g.undo_log != null:
				g.undo_log.record(s, &"memory", s.memory)
			s.memory = s.memory.duplicate()
			s.memory.erase("holding")
			s.memory.erase("weaponry_untaps")
		return
	for row in held:
		var i := g.find_instance(int(row[0]))
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and not i.phased_out \
				and i.layer_timestamp == int(row[1]) and i.is_creature():
			i.cur_power += 2
			i.cur_toughness += 2

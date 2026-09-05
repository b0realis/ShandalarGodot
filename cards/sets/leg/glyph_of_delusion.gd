extends CardScript
## Glyph of Delusion — {U} — Instant — (leg, common)
## Oracle: Put X glyph counters on target creature that target Wall blocked
##         this turn, where X is the power of that blocked creature. The
##         creature gains "This creature doesn't untap during your untap
##         step if it has a glyph counter on it" and "At the beginning of
##         your upkeep, remove a glyph counter from this creature."
##
## Implementation: TWO targets, as printed — the creature, then the Wall
## that blocked it. The Wall slot can target only Walls (so Wall of
## Shadows is immune to it, as to the rest of the Glyph cycle), and "that
## target Wall blocked this turn" is a requirement stated relative to the
## creature slot: a TargetSpec.sibling_filter reads the block history
## (CardInstance.blocked_ids_this_turn, wave 48) against the creature
## actually named, so a Wall that blocked something ELSE is refused with
## `Illegal target (blocked).` The creature slot carries the same history
## as a plain filter — a creature no Wall blocked can be part of no legal
## pair — which is what keeps the first prompt's candidates honest. Both
## are real targets, and the counters land only while both are legal: a
## Wall that has left makes "that target Wall blocked" untrue (CR 608.2b).
##
## X is the victim's live power, so a pumped attacker stays down longer.
## The two granted abilities are engine-side turn-based rules keyed on the
## "glyph" counter kind (see MtgGame's untap and upkeep steps), so they
## keep working after the Glyph is in the graveyard. Nothing on the
## printed card says the Wall must be yours: any Wall that blocked it
## qualifies.


## Did any Wall block [param inst] this turn? (Necessary for a legal pair.)
static func _some_wall_blocked_it(game: MtgGame, inst: CardInstance) -> bool:
	for wall in game.all_battlefield():
		if wall.has_subtype("wall") and wall.blocked_ids_this_turn.has(inst.id):
			return true
	return false


static func _is_wall(inst: CardInstance) -> bool:
	return inst.has_subtype("wall")


## "… that TARGET WALL blocked this turn": [param earlier] holds the
## creature slot's ref.
static func _blocked_the_first(game: MtgGame, _source: CardInstance,
		candidate: TargetRef, earlier: Array) -> bool:
	var wall := game.find_instance(candidate.instance_id)
	return wall != null and wall.blocked_ids_this_turn.has(earlier[0].instance_id)


func build() -> CardData:
	var creature := TargetSpec.creature(
			"target creature that target Wall blocked this turn") \
		.with_game_filter(_some_wall_blocked_it).because(TargetSpec.WHY["blocked"])
	var wall := TargetSpec.creature("target Wall", _is_wall).only_walls() \
		.because(TargetSpec.WHY["subtype"]) \
		.with_sibling_filter(_blocked_the_first, TargetSpec.WHY["blocked"])
	return CardData.new("Glyph of Delusion", "{U}", Mtg.CardType.INSTANT) \
		.spell(GlyphOfDelusionEffect.new(creature, wall)) \
		.spell(WallSlotEffect.new(wall)) \
		.oracle("Put X glyph counters on target creature that target Wall blocked this turn, where X is the power of that blocked creature. The creature gains \"This creature doesn't untap during your untap step if it has a glyph counter on it\" and \"At the beginning of your upkeep, remove a glyph counter from this creature.\"")


## The creature slot — and the counters, which land only if the Wall slot
## is still a legal target too. The engine re-judges each effect's OWN
## ref (CR 608.2c); the Wall's is the second effect's, so it is re-judged
## here with the same spec and the creature's ref as its sibling.
class GlyphOfDelusionEffect extends EffectBase:
	var wall_spec: TargetSpec

	func _init(spec: TargetSpec, p_wall_spec: TargetSpec) -> void:
		target_spec = spec
		wall_spec = p_wall_spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := game.find_instance(target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			return
		var slots := game.current_targets()
		if slots.size() < 2 or not wall_spec.is_legal(game, slots[1], source, [target]):
			game.log_line("Glyph of Delusion: its Wall is no longer a legal target")
			return
		var x: int = maxi(victim.cur_power, 0)
		if x <= 0:
			return
		game.add_counters(victim, "glyph", x)

	func describe() -> String:
		return "puts glyph counters equal to its power on a creature the target Wall blocked"


## The Wall slot: a target and nothing more — the work is in the creature
## slot's effect, which can see both.
class WallSlotEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass

	func describe() -> String:
		return "the Wall that blocked it"

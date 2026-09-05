extends CardScript
## Arena — Land — (phpr, rare)
## Oracle: {3}, {T}: Tap target creature you control and target creature of
##         an opponent's choice they control. Those creatures fight each
##         other. (Each deals damage equal to its power to the other.)
##
## Implementation: TWO targets, one per player. The activator names the
## creature they put in the ring; the opponent's champion is a target the
## OPPONENT chooses (TargetSpec.opponent_chooses — asked of them as the
## ability is activated, CR 601.2c, through the same hold that asks a
## human which body a sacrifice cost eats). Both are real targets: the
## ability can't be activated with no creature on the other side, a
## champion with shroud or protection from the Arena's colourlessness is
## not on the list, and one that leaves in response is an illegal target
## on resolution.
##
## The fight (CR 701.12): the two effects tap their own target, and the
## second — the champion's — deals the blows only when BOTH creatures are
## still legal targets and on the battlefield (701.12b: "if either creature
## is no longer on the battlefield or is an illegal target, no damage is
## dealt"); the legal one is still tapped, because the tapping is not part
## of the fight. The blows are simultaneous, dealt inside a
## begin_simultaneous bracket, so two 2/2s trade rather than the first one
## dying and the second walking away.
##
## The champion's controller picks from a list ordered from THEIR point of
## view against the creature the activator sent in — a body that kills it
## and survives first, then one that at least kills it, then the survivor
## they would miss least — and that first entry is what their heuristic
## sends.
##
## `@ARENA`, `Program/promptsX1.txt:26`, is the original's own prompt
## (`Select target creature.` / `Selected for Arena.`) — both players are
## asked with its first line.


func build() -> CardData:
	var mine := EnterEffect.new()
	return CardData.new("Arena", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new("{3}", true,
			[mine, FightEffect.new(mine.target_spec)],
			"{3}, {T}: Tap target creature you control and target creature of an opponent's choice they control. Those creatures fight each other.")) \
		.oracle("{3}, {T}: Tap target creature you control and target creature of "
			+ "an opponent's choice they control. Those creatures fight each other. "
			+ "(Each deals damage equal to its power to the other.)")


## "Tap target creature you control" — the activator's own pick. Tapped
## here whether or not the champion is still around to fight it.
class EnterEffect extends EffectBase:
	func _init() -> void:
		# `@ARENA` entry 1, Program/promptsX1.txt:28.
		target_spec = TargetSpec.creature("target creature you control") \
			.with_source_filter(EnterEffect._yours)

	static func _yours(_game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return source == null or inst.controller_id == source.controller_id

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var mine := game.find_instance(target.instance_id)
		if mine != null and mine.zone == Mtg.Zone.BATTLEFIELD:
			game.tap_permanent(mine)

	func describe() -> String:
		return "tap your creature"


## "… and target creature of an opponent's choice they control. Those
## creatures fight each other." Tapping the champion is unconditional; the
## fight needs both bodies legal (CR 701.12b).
class FightEffect extends EffectBase:
	## The activator's own spec, to re-check their creature's legality on
	## resolution the way the engine checked it when the ability went on
	## the stack.
	var mine_spec: TargetSpec

	func _init(p_mine_spec: TargetSpec) -> void:
		mine_spec = p_mine_spec
		target_spec = TargetSpec.creature(
				"target creature of an opponent's choice they control") \
			.with_source_filter(FightEffect._theirs) \
			.opponent_chooses(FightEffect._champion_order,
				"Select target creature.")   # `@ARENA` entry 1

	static func _theirs(_game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return source == null or inst.controller_id != source.controller_id

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var theirs := game.find_instance(target.instance_id)
		if theirs == null or theirs.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.tap_permanent(theirs)
		var refs: Array = game.current_targets()
		if refs.is_empty():
			return
		var mine_ref: TargetRef = refs[0]
		var mine := game.find_instance(mine_ref.instance_id)
		# CR 701.12b: no blow is struck unless both are still creatures on
		# the battlefield AND legal targets — the activator's own creature
		# is checked here because the engine only drops ILLEGAL refs per
		# effect, and this effect's ref is the champion's.
		if mine == null or mine.zone != Mtg.Zone.BATTLEFIELD \
				or not mine.is_creature() or not theirs.is_creature() \
				or not mine_spec.is_legal(game, mine_ref, source):
			game.log_line("Arena: no fight — %s is gone" % (
				mine_ref.to_string() if mine == null else mine.data.card_name))
			return
		# CR 701.12: the two blows are simultaneous, so two equals trade.
		game.begin_simultaneous()
		game.deal_damage(mine, TargetRef.card(theirs), mine.cur_power)
		game.deal_damage(theirs, TargetRef.card(mine), theirs.cur_power)
		game.end_simultaneous()

	## THEIR order, against the creature the activator sent in (readable as
	## the first current target while the engine sorts): a champion that
	## kills it and lives, then one that kills it, then the survivor they
	## would miss least, then the loser they would miss least.
	static func _champion_order(game: MtgGame, _source: CardInstance,
			a: TargetRef, b: TargetRef) -> bool:
		var foe: CardInstance = null
		var refs: Array = game.current_targets()
		if not refs.is_empty():
			foe = game.find_instance(refs[0].instance_id)
		var ia := game.find_instance(a.instance_id)
		var ib := game.find_instance(b.instance_id)
		var sa := _score(ia, foe)
		var sb := _score(ib, foe)
		if sa != sb:
			return sa > sb
		# A winner: the cheapest that still wins; a loser: the cheapest.
		var va := ia.cur_power + ia.cur_toughness
		var vb := ib.cur_power + ib.cur_toughness
		if va != vb:
			return va < vb
		return ia.id < ib.id

	static func _score(body: CardInstance, foe: CardInstance) -> int:
		if foe == null:
			return 0
		var kills := body.cur_power >= foe.cur_toughness - foe.damage
		var lives := foe.cur_power < body.cur_toughness - body.damage
		return (2 if kills else 0) + (1 if lives else 0)

	func describe() -> String:
		return "their champion fights it"

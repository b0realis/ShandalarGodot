extends CardScript
## Cuombajj Witches — {B}{B} — Creature — Human Wizard — 1/3 — (arn, common)
## Oracle: {T}: This creature deals 1 damage to any target and 1 damage to
##         any target of an opponent's choice.
##
## Implementation: two 1-damage effects on one activation, each with its
## own target — the first the activator's, the second a target the
## OPPONENT chooses (TargetSpec.opponent_chooses), named as the ability
## is activated (CR 601.2c) through the same hold that asks a human which
## body a sacrifice cost eats. "Any target" of THEIR choice is any
## creature or player, the Witches' controller's face included, so the
## question is an OPTION list of names when a player is on it. Both are
## real targets: a creature with shroud is on nobody's list, and each
## shot fizzles on its own if what it was aimed at has left (CR 608.2b —
## the other still lands). The opponent may aim at the same object the
## activator did (CR 601.2c: "the same object or player can be chosen
## once for each instance of the word 'target'").
##
## Their list is ordered from their point of view: a creature of the
## activator's the ping kills, then the activator's face, then the
## activator's other creatures (biggest first), then their own things —
## and that first entry is what their heuristic takes.
##
## `@CUOMBAJJ_WITCHES`, `Program/promptsX1.txt:92`, is the original's own
## prompt (`Select target creature or player.` / `to deal 1 damage.`),
## and both players are asked with its first line.


func build() -> CardData:
	var theirs := DamageEffect.new(1).any_target()
	theirs.target_spec.description = "any target of an opponent's choice"
	theirs.target_spec.opponent_chooses(CuombajjOrder.first_before_second,
		"Select target creature or player.")
	return CardData.new("Cuombajj Witches", "{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 3) \
		.with_subtypes(["human", "wizard"]) \
		.activated(ActivatedAbility.new(
			"", true, [DamageEffect.new(1).any_target(), theirs],
			"{T}: Cuombajj Witches deals 1 damage to any target and 1 damage to any "
			+ "target of an opponent's choice.")) \
		.oracle("{T}: This creature deals 1 damage to any target and 1 damage to any "
			+ "target of an opponent's choice.")


## The opponent's order for the return shot, from their point of view.
class CuombajjOrder:
	static func first_before_second(game: MtgGame, source: CardInstance,
			a: TargetRef, b: TargetRef) -> bool:
		var sa := _score(game, source, a)
		var sb := _score(game, source, b)
		if sa != sb:
			return sa > sb
		return a.to_string() < b.to_string()

	## Higher is better for the chooser: a kill on the activator's side,
	## the activator's face, a bigger creature of theirs, then the
	## chooser's own things last.
	static func _score(game: MtgGame, source: CardInstance, ref: TargetRef) -> int:
		var activator: int = source.controller_id if source != null else -1
		if ref.is_player:
			return 800 if ref.player_id == activator else 0
		var inst := game.find_instance(ref.instance_id)
		if inst == null:
			return 0
		if inst.controller_id != activator:
			return 100 - inst.cur_power - inst.cur_toughness
		if inst.cur_toughness - inst.damage <= 1:
			return 900 + inst.cur_power
		return 500 + inst.cur_power + inst.cur_toughness

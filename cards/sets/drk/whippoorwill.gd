extends CardScript
## Whippoorwill — {G} — Creature — Bird — 1/1 — (drk, uncommon)
## Oracle: {G}{G}, {T}: Target creature can't be regenerated this turn.
##         Damage that would be dealt to that creature this turn can't be
##         prevented or dealt instead to another permanent or player. When
##         the creature dies this turn, exile the creature.
##
## Implementation: three per-turn flags on the victim, all of which the
## engine already keeps or now keeps, and all of which are cleared at
## cleanup:
## - `regeneration_banned_this_turn` (CR 701.15 — the shield simply does
##   not replace the destruction);
## - `damage_unpreventable_this_turn` (NEW): MtgGame._land_damage_impl
##   skips every prevention and redirection gate for that creature, which
##   includes PROTECTION, since CR 702.16e makes protection prevent the
##   damage — the printed line says "can't be prevented" without exception;
## - `exile_instead_of_dying` (CR 614.1c), so the body never reaches the
##   graveyard for a Regrowth or an Animate Dead to find.
##
## Two green mana and a bird answers a regenerating, protected, Circle-shielded
## creature outright, and it is the exiling that makes it a Dark card.


func build() -> CardData:
	return CardData.new("Whippoorwill", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["bird"]) \
		.activated(ActivatedAbility.new("{G}{G}", true, [MarkEffect.new()],
			"{G}{G}, {T}: Target creature can't be regenerated this turn, damage to it can't be prevented or redirected, and it is exiled if it dies this turn.")) \
		.oracle("{G}{G}, {T}: Target creature can't be regenerated this turn. "
			+ "Damage that would be dealt to that creature this turn can't be "
			+ "prevented or dealt instead to another permanent or player. When the "
			+ "creature dies this turn, exile the creature.")


class MarkEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		inst.regeneration_banned_this_turn = true
		inst.damage_unpreventable_this_turn = true
		inst.exile_instead_of_dying = true
		game.log_line("%s is marked by the Whippoorwill" % inst.data.card_name)

	func describe() -> String:
		return "marks a creature: no regeneration, no prevention, exiled if it dies"

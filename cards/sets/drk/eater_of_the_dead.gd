extends CardScript
## Eater of the Dead — {4}{B} — Creature — Horror — 3/4 — (drk, uncommon)
## Oracle: {0}: If this creature is tapped, exile target creature card
##         from a graveyard and untap this creature.
##
## Implementation: a FREE ability with an intervening condition (it does
## nothing unless the Eater is already tapped) whose payload exiles a
## creature card from EITHER graveyard and untaps the Eater. Because the
## cost is {0} and the untap is part of the effect, it can eat a whole
## graveyard in one priority window — and untapping mid-combat means it
## blocks, deals damage, then unblocks itself for the next attacker.


func build() -> CardData:
	return CardData.new("Eater of the Dead", "{4}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 4) \
		.with_subtypes(["horror"]) \
		.activated(ActivatedAbility.new(
			"", false, [FeastEffect.new()],
			"{0}: If Eater of the Dead is tapped, exile target creature card from a "
			+ "graveyard and untap Eater of the Dead.") \
			.only_if(_is_tapped)) \
		.oracle("{0}: If this creature is tapped, exile target creature card from a "
			+ "graveyard and untap this creature.")


static func _is_tapped(_game: MtgGame, source: CardInstance) -> String:
	return "" if source.tapped else "only while it is tapped"


class FeastEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD)

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if source.zone != Mtg.Zone.BATTLEFIELD or not source.tapped:
			return   # the intervening "if", re-checked at resolution (CR 603.4)
		var corpse := game.find_instance(target.instance_id)
		if corpse == null or corpse.zone != Mtg.Zone.GRAVEYARD:
			return
		game.exile_from_graveyard(corpse)
		game.untap_permanent(source)

	func describe() -> String:
		return "exiles a creature card from a graveyard and untaps this creature"

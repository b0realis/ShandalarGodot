extends CardScript
## Tracker — {2}{G} — Creature — Human — 2/2 — (drk, rare)
## Oracle: {G}{G}, {T}: This creature deals damage equal to its power to
##         target creature. That creature deals damage equal to its power
##         to this creature.
##
## Implementation: a card-local FIGHT effect — both halves use LIVE power
## and both are dealt by MtgGame.deal_damage, so protection, prevention
## and damage immunities all apply in both directions. Not combat damage,
## so a Gaseous Form on either side does not stop it.


func build() -> CardData:
	return CardData.new("Tracker", "{2}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human"]) \
		.activated(ActivatedAbility.new(
			"{G}{G}", true, [FightEffect.new()],
			"{G}{G}, {T}: Tracker deals damage equal to its power to target creature. "
			+ "That creature deals damage equal to its power to Tracker.")) \
		.oracle("{G}{G}, {T}: This creature deals damage equal to its power to target "
			+ "creature. That creature deals damage equal to its power to this creature.")


class FightEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var foe := game.find_instance(target.instance_id)
		if foe == null or foe.zone != Mtg.Zone.BATTLEFIELD:
			return
		var mine := source.cur_power
		var theirs := foe.cur_power
		if mine > 0:
			game.deal_damage(source, TargetRef.card(foe), mine)
		if theirs > 0 and source.zone == Mtg.Zone.BATTLEFIELD:
			game.deal_damage(foe, TargetRef.card(source), theirs)

	func describe() -> String:
		return "fights target creature"

extends CardScript
## Quarum Trench Gnomes — {3}{R} — Creature — Gnome — 1/1 — (leg, rare)
## Oracle: {T}: If target Plains is tapped for mana, it produces colorless
##         mana instead of white mana. (This effect lasts indefinitely.)
##
## Implementation: an indefinite TEXT CHANGE on the land (CR 613 layer 3) —
## the "mana_color" kind rewrites its mana ability from {W} to {C}, and the
## change rides on the land until it leaves the battlefield.


static func _is_plains(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("plains")


func build() -> CardData:
	return CardData.new("Quarum Trench Gnomes", "{3}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["gnome"]) \
		.activated(ActivatedAbility.new("", true,
			[DrainPlainsEffect.new(TargetSpec.new(
				TargetSpec.Kind.PERMANENT, "target Plains", _is_plains))],
			"{T}: If target Plains is tapped for mana, it produces colorless mana instead of white mana.")) \
		.oracle("{T}: If target Plains is tapped for mana, it produces colorless mana instead of white mana. (This effect lasts indefinitely.)")


class DrainPlainsEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var land := game.find_instance(target.instance_id)
		if land == null or land.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.change_text(land, "mana_color", Mtg.ManaColor.W, Mtg.ManaColor.C)

	func describe() -> String:
		return "target Plains produces colorless mana instead of white"

extends CardScript
## Winter Blast — {X}{G} — Sorcery — (4ed, uncommon)
## Oracle: Tap X target creatures. Winter Blast deals 2 damage to each of
##         those creatures with flying.
##
## Implementation: one effect, because the second sentence talks about
## "those creatures" — the same group the first sentence tapped. Taking the
## whole group at once is exactly what EffectBase.resolve_multi is for.


func build() -> CardData:
	return CardData.new("Winter Blast", "{X}{G}", Mtg.CardType.SORCERY) \
		.spell(TapAndShootFlyersEffect.new()) \
		.oracle("Tap X target creatures. Winter Blast deals 2 damage to each of those creatures with flying.")


class TapAndShootFlyersEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		x_targets()

	func resolve_multi(game: MtgGame, source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		var hit: Array[CardInstance] = []
		for ref in targets:
			var inst := game.find_instance(ref.instance_id)
			if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
				continue
			game.tap_permanent(inst)
			hit.append(inst)
		# The 2 damage is dealt AFTER every tap, to the flyers among the
		# creatures that were tapped this way.
		for inst in hit:
			if inst.zone == Mtg.Zone.BATTLEFIELD and inst.has_keyword(Mtg.Keyword.FLYING):
				game.deal_damage(source, TargetRef.card(inst), 2)

	func describe() -> String:
		return "taps X target creatures and deals 2 damage to each of them with flying"

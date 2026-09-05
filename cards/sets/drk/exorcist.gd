extends CardScript
## Exorcist — {W}{W} — Creature — Human Cleric — 1/1 — (drk, rare)
## Oracle: {1}{W}, {T}: Destroy target black creature.
##
## Implementation: Northern Paladin's little sibling — mana + tap
## activated destruction, filtered to BLACK creatures (color from cost).


func build() -> CardData:
	var spec := TargetSpec.creature("target black creature", _is_black)
	return CardData.new("Exorcist", "{W}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"{1}{W}", true,
			[DestroyEffect.new(spec)],
			"{1}{W}, {T}: Destroy target black creature.")) \
		.oracle("{1}{W}, {T}: Destroy target black creature.")


static func _is_black(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.B) != 0

extends CardScript
## Ramses Overdark — {2}{U}{U}{B}{B} — Legendary Creature — Human Assassin — 4/3 — (leg, rare)
## Oracle: {T}: Destroy target enchanted creature.
##
## Implementation: a free tap DestroyEffect whose filter demands the
## target carry at least one Aura — enchanted by ANYONE, so a Holy
## Strength you cast on their bear turns Ramses into repeatable removal.
## The classic Legends assassin plus one aura is a soft lock.


func build() -> CardData:
	var spec := TargetSpec.creature("target enchanted creature")
	spec.with_game_filter(_is_enchanted)
	return CardData.new("Ramses Overdark", "{2}{U}{U}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(4, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "assassin"]) \
		.activated(ActivatedAbility.new(
			"", true, [DestroyEffect.new(spec)],
			"{T}: Destroy target enchanted creature.")) \
		.oracle("{T}: Destroy target enchanted creature.")


static func _is_enchanted(game: MtgGame, inst: CardInstance) -> bool:
	for aura_id in inst.attachments:
		var aura := game.find_instance(aura_id)
		if aura != null and aura.data.is_aura():
			return true
	return false

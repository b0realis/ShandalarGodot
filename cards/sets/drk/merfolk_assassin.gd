extends CardScript
## Merfolk Assassin — {U}{U} — Creature — Merfolk Assassin — 1/2 — (drk, uncommon)
## Oracle: {T}: Destroy target creature with islandwalk.
##
## Implementation: a free tap DestroyEffect filtered on LIVE landwalk —
## so it kills a printed islandwalker (Lord of Atlantis' merfolk) or
## anything a Fishliver Oil just enchanted. A blue mirror-match hoser
## with the narrowest possible window.


func build() -> CardData:
	var spec := TargetSpec.creature("target creature with islandwalk", _has_islandwalk)
	return CardData.new("Merfolk Assassin", "{U}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["merfolk", "assassin"]) \
		.activated(ActivatedAbility.new(
			"", true, [DestroyEffect.new(spec)],
			"{T}: Destroy target creature with islandwalk.")) \
		.oracle("{T}: Destroy target creature with islandwalk.")


static func _has_islandwalk(inst: CardInstance) -> bool:
	return inst.cur_landwalk.has("island")

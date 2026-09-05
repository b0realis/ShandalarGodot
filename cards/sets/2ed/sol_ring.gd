extends CardScript
## Sol Ring — {1} — Artifact (Alpha, uncommon)
## Oracle: {T}: Add {C}{C}.
##
## Implementation: a two-colorless ManaAbility. Artifacts have no summoning
## sickness for {T} abilities (CR 302.6 applies only to creatures), so it
## can tap the turn it arrives — the engine's sickness check is
## creature-only, and the tests pin that behavior. Restricted in
## Shandalar's deck rules.


func build() -> CardData:
	return CardData.new("Sol Ring", "{1}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 2)) \
		.oracle("{T}: Add {C}{C}.")

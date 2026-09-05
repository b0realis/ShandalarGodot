extends CardScript
## Samite Healer — {1}{W} — Creature — Human Cleric — 1/1 — (2ed, common)
## Oracle: {T}: Prevent the next 1 damage that would be dealt to any
##         target this turn.
##
## Implementation: tap ability whose payload is PreventDamageEffect(1) —
## one point into the target's prevention pool, drained by deal_damage
## before damage marks. The classic white utility body: it turns every
## 1-power attacker into a blank and every Bolt into a Shock.


func build() -> CardData:
	return CardData.new("Samite Healer", "{1}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[PreventDamageEffect.new(1).any_target()],
			"{T}: Prevent the next 1 damage to any target this turn.")) \
		.oracle("{T}: Prevent the next 1 damage that would be dealt to any target this turn.")

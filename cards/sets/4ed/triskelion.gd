extends CardScript
## Triskelion — {6} — Artifact Creature — Construct — 1/1 — (4ed, rare)
## Oracle: This creature enters with three +1/+1 counters on it.
##         Remove a +1/+1 counter from this creature: It deals 1 damage to
##         any target.
##
## Implementation: CardData.with_enters_counters plants the three
## counters; ActivatedAbility.with_counter_cost makes removing one a real
## COST (paid on activation, CR 601.2h — three counters buy exactly three
## pings, however many activations are stacked), and the payload is a
## 1-damage DamageEffect. Six mana for a 4/4 that can shoot three times —
## including three pings at the face when it is about to die.


func build() -> CardData:
	return CardData.new("Triskelion", "{6}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["construct"]) \
		.with_enters_counters("+1/+1", 3) \
		.activated(ActivatedAbility.new(
			"", false, [DamageEffect.new(1).any_target()],
			"Remove a +1/+1 counter from Triskelion: It deals 1 damage to any target.") \
			.with_counter_cost("+1/+1", 1)) \
		.oracle("This creature enters with three +1/+1 counters on it.\nRemove a "
			+ "+1/+1 counter from this creature: It deals 1 damage to any target.")

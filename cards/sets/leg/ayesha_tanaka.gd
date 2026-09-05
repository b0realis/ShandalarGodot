extends CardScript
## Ayesha Tanaka — {W}{W}{U}{U} — Legendary Creature — Human Artificer — 2/2 — (leg, rare)
## Oracle: Banding
##         {T}: Counter target activated ability from an artifact source
##         unless that ability's controller pays {W}. (Mana abilities can't
##         be targeted.)
##
## Implementation: Rust's effect with a ransom attached — the ability's OWN
## controller is offered the {W} (CounterAbilityEffect.unless_they_pay), and
## the ability survives only if they can pay and choose to. Whose choice it
## is matters: this is the one artifact answer in the pool that the artifact's
## controller can buy their way out of.
##
## Banding is the printed keyword; attack bands are implemented, defensive
## banding is not (engine-wide, docs/ROADMAP.md).
##
## The ransom is asked inside the ability's own resolution, so the §1.3
## pre-flight reaches it and a human seat is really asked; the heuristic
## agent pays whenever it can afford to.


func build() -> CardData:
	return CardData.new("Ayesha Tanaka", "{W}{W}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "artificer"]) \
		.with_keywords([Mtg.Keyword.BANDING]) \
		.activated(ActivatedAbility.new("", true, [
				CounterAbilityEffect.new(
					"target activated ability from an artifact source",
					CounterAbilityEffect.from_an_artifact) \
					.unless_they_pay("{W}")],
			"{T}: Counter target activated ability from an artifact source unless that ability's controller pays {W}.")) \
		.oracle("Banding\n{T}: Counter target activated ability from an artifact "
			+ "source unless that ability's controller pays {W}. (Mana abilities "
			+ "can't be targeted.)")

extends CardScript
## Will-o'-the-Wisp — {B} — Creature — Spirit — 0/1 — (2ed, rare)
## Oracle: Flying (This creature can't be blocked except by creatures with
##         flying or reach.)
##         {B}: Regenerate this creature. (The next time this creature
##         would be destroyed this turn, instead tap it, remove it from
##         combat, and heal all damage on it.)
##
## Implementation: the immortal chump-blocker — a one-mana 0/1 flyer with
## the standard regeneration ability. Blocks a Shivan Dragon forever as
## long as {B} keeps flowing.


func build() -> CardData:
	return CardData.new("Will-o'-the-Wisp", "{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["spirit"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[RegenerateEffect.new()],
			"{B}: Regenerate this creature.")) \
		.oracle("Flying\n{B}: Regenerate this creature.")

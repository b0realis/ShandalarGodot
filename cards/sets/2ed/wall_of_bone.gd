extends CardScript
## Wall of Bone — {2}{B} — Creature — Skeleton Wall — 1/4 (2ed, uncommon)
## Oracle: Defender (This creature can't attack.)
##         {B}: Regenerate this creature.
##
## Implementation: DEFENDER + the Drudge Skeletons regeneration package on
## a wall body — black's undying blocker. Note it IS a Wall by subtype, so
## Juggernaut walks past it (cant_be_blocked_by).


func build() -> CardData:
	return CardData.new("Wall of Bone", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 4) \
		.with_subtypes(["skeleton", "wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[RegenerateEffect.new()],
			"{B}: Regenerate this creature.")) \
		.oracle("Defender\n{B}: Regenerate this creature.")

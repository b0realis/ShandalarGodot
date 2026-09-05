extends CardScript
## Jandor's Ring — {6} — Artifact — (arn, rare)
## Oracle: {2}, {T}, Discard the last card you drew this turn: Draw a card.
##
## Implementation: the discard is a COST, and a specific card — the last
## entry of MtgPlayer.drawn_this_turn (ActivatedAbility.
## discard_last_drawn_cost). Nobody chooses anything: with no draw this
## turn the ability can't be activated, and neither can it once that card
## has left the hand (played, discarded — CR 601.2g). A cost discard, so
## Library of Leng does not offer the top of the library for it (Duel.hlp,
## Library of Leng: cost discards do not qualify). Then a fresh card.
##
## The 1997 form was looser — *"Discard a card you just drew"*, asked with
## `@JANDORS_RING` (Program/promptsX1.txt:221, *"Select card drawn this
## turn to discard."*), so with several draws in one turn the original let
## you pick among them; the printed Oracle names THE LAST one, and that is
## what is paid here. With the usual one draw a turn the two coincide.
## Duel.hlp's ruling is the same on both: "if an effect has you draw more
## than one card, you draw them all at once. So you would know everything
## you drew when deciding whether to use the Ring."


func build() -> CardData:
	return CardData.new("Jandor's Ring", "{6}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{2}", true, [DrawEffect.new(1)],
			"{2}, {T}, Discard the last card you drew this turn: Draw a card.") \
			.with_discard_last_drawn_cost()) \
		.oracle("{2}, {T}, Discard the last card you drew this turn: Draw a card.")

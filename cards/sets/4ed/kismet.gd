extends CardScript
## Kismet — {3}{W} — Enchantment — (4ed, uncommon)
## Oracle: Artifacts, creatures, and lands your opponents control enter
##         tapped.
##
## Implementation: a REPLACEMENT effect, which is what the printed card is
## (CR 614.1c) — CardData.taps_permanents_entering, asked by MtgGame as the
## permanent arrives and before it is ever on the battlefield untapped. It
## therefore does NOT trip a "whenever this becomes tapped" trigger:
## a Psychic Venom on a Kismet-tapped land, a Powerleech or a Haunting Wind
## all stay quiet, exactly as they do in paper.
##
## Types are read LIVE (CONTRIBUTING.md rule 5), so an animated artifact arrives
## tapped for the same reason a creature does. A second Kismet changes
## nothing: the replacement is a yes/no question, asked of the board until
## one permanent says yes.


func build() -> CardData:
	return CardData.new("Kismet", "{3}{W}", Mtg.CardType.ENCHANTMENT) \
		.taps_permanents_entering(_theirs) \
		.oracle("Artifacts, creatures, and lands your opponents control enter tapped.")


static func _theirs(_game: MtgGame, source: CardInstance,
		entering: CardInstance, controller: int) -> bool:
	if controller == source.controller_id:
		return false
	return entering.is_land() or entering.is_creature() \
		or entering.is_type(Mtg.CardType.ARTIFACT)

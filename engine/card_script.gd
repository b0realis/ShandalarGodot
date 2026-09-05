class_name CardScript
extends RefCounted
## Base class for every card file under cards/sets/.
##
## A card file is the SINGLE home of one card: its rules (as a CardData
## built from effects/abilities) and its documentation (the file's doc
## comment: oracle text, rulings that matter, implementation notes, known
## simplifications). One card per file, filename = snake_case card name.
##
## The only requirement is overriding [method build]:
## [codeblock]
## extends CardScript
## func build() -> CardData:
##     return CardData.new("Grizzly Bears", "{1}{G}", Mtg.CardType.CREATURE) \
##         .pt(2, 2).with_subtypes(["bear"]) \
##         .oracle("")   # vanilla — no rules text
## [/codeblock]
## The CardRegistry loader instantiates the script, calls build(), stamps
## the set code from the folder name, and registers the result by card name.
## See docs/adding-cards.md for the full authoring walkthrough and checklist.


## Override: construct and return this card's CardData. Called once, at
## registry load time — keep it pure (no game access, no randomness).
func build() -> CardData:
	push_error("CardScript.build not overridden in %s" % get_script().resource_path)
	return null

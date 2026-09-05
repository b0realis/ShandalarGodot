class_name ProxyCard
extends RefCounted
## THE PROXY — a paper stand-in for a card this game does not implement,
## so that a deck naming one can still be READ, BUILT, SAVED and LOOKED AT.
##
## [QoL], and entirely ours. No 1997 source has a word for it: `grep -a`
## over `Program/UIStrings.txt`, `Program/Text.res`, `Program/prompts*.txt`
## and the genuine 1997 `s30/assets/text/Menus.txt` finds neither "proxy"
## nor "import" nor "paste" nor "blank" anywhere (2026-09-01). The 1997
## Deck Builder had ONE Inventory — *"every Magic: The Gathering card
## included in the game"* — and therefore nothing to stand in for a card
## it did not include. So this whole surface is marked as ours rather than
## dressed up as theirs.
##
## ============================== WHAT A PROXY IS, EXACTLY ================
##
## **A card name a deck holds that the [CardRegistry] does not know.**
## That is the entire definition, and everything else falls out of it:
##
##  * it needs NO MARKER IN THE FILE, so a proxy round-trips through all
##    three deck formats for free ([method DeckList.parse],
##    [method DeckList.parse_dck]) and a build made before proxies existed
##    reads the same file back unchanged;
##  * A PROXY GRADUATES BY ITSELF. The pool grows every week; the day a
##    card is implemented, the deck that proxied it is holding the real
##    card and plays. That is exactly what *"a stand-in for a card I mean
##    to have later"* should do, and it is why the definition is a
##    QUESTION ASKED OF THE REGISTRY rather than a flag written down;
##  * and it can never be played, because everything that reaches a duel
##    resolves names THROUGH that same registry.
##
## ================================ THE HARD BOUNDARY =====================
##
## A proxy is a picture with no rules behind it. One that reached
## [MtgGame] would be a card that cannot resolve — a crash, or worse, a
## library quietly one card short ([method MtgGame._build_library] skips a
## name it cannot resolve). So:
##
##  1. **A PROXY NEVER ENTERS THE REGISTRY.** [method data_for] BUILDS a
##     [CardData] and hands it straight back; nothing in this file calls
##     [method CardRegistry.register], and nothing may. The registry is the
##     set of things that can be played, `test_registry_loaded_the_pool`
##     pins its size, and a proxy in it would be a bug that pinned itself.
##  2. **EVERY DOOR INTO A DUEL ASKS [method refusal_for] FIRST** — the
##     battle-setup screen's live legality note and its `Go!` gate
##     (`game/setup_screen.gd`), and the Deck Lab at parse time
##     (`tools/simulate.gd`), which is where `--format` already refuses.
##  3. **[method DeckList.load_file]'s STRICT MODE is the floor under both
##     of them**: an unknown name is an error there, it always was, and
##     that must not change. Import needs the LENIENT path, which is the
##     same `strict = false` the deck converter has always used.
##
## `tests/unit/test_proxy_card.gd` pins all three, and would fail if a
## proxy could reach a duel by any of those doors.

## What a proxy writes where a card writes its rules text. The owner's own
## word, lower-case, exactly as asked for: *"To the card text we write
## proxy."*
const RULES_TEXT := "proxy"

## The one-line explanation the enlarged proxy shows under that word, and
## the sentence every refusal below is built out of.
const EXPLANATION := "A visual stand-in for a card this game does not " \
	+ "implement. It helps you see the deck; it cannot be played."


## Is [param card_name] a proxy — a name no implemented card answers to?
##
## Asked of the REGISTRY every time rather than cached, because the answer
## legitimately changes: a card graduating out of `cards/todo/` turns its
## proxies into real cards, and a deck on screen must follow. The look-up
## is one Dictionary hit ([method CardRegistry.has_card]).
##
## The empty string is NOT a proxy — it is nothing at all, and a deck line
## that produced one would be a parse bug, not a stand-in.
static func is_proxy(card_name: String) -> bool:
	if card_name.strip_edges() == "":
		return false
	return not CardRegistry.has_card(card_name)


## The distinct proxy names in [param cards] (and [param sideboard], which
## is part of the deck for every rule in this project — see
## [method DeckFormat.legal]), SORTED, so a refusal reads the same way
## twice and a test can compare it.
static func names_in(cards: Array, sideboard: Array = []) -> Array[String]:
	var seen := {}
	for pile in [cards, sideboard]:
		for entry in pile:
			var card_name := String(entry)
			if is_proxy(card_name):
				seen[card_name] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


## WHY A DECK HOLDING [param names] CANNOT BE PLAYED, naming every one of
## them — "" when there are none. This project's action-method convention
## (CONTRIBUTING.md rule 3), so every gate can simply show the string.
##
## It NAMES THE CARDS on purpose. A refusal that said only "this deck has
## proxies" would leave the player hunting a 200-card list for the three
## they have to replace.
static func refusal(names: Array) -> String:
	if names.is_empty():
		return ""
	var listed := ", ".join(PackedStringArray(names))
	if names.size() == 1:
		return ("This deck cannot be played: %s is a proxy. %s Replace it "
			+ "with a card from the pool, or keep the deck for building "
			+ "and visualising.") % [listed, EXPLANATION]
	return ("This deck cannot be played: %d of its cards are proxies — %s. "
		+ "%s Replace them with cards from the pool, or keep the deck for "
		+ "building and visualising.") % [names.size(), listed, EXPLANATION]


## [method refusal] over an expanded deck: "" when every name is a real
## card. THE ONE CALL every duel entry point makes.
static func refusal_for(cards: Array, sideboard: Array = []) -> String:
	return refusal(names_in(cards, sideboard))


## THE PROXY'S CARD DATA — name, the word `proxy` where rules text goes,
## and nothing else at all: no cost, no type, no colour, no power. A proxy
## has no colour to claim, which is the whole reason it is drawn on plain
## paper rather than in a coloured frame.
##
## It exists so the Deck Builder's surfaces, which pass [CardData] around
## ([method CardArea.set_entries]), can carry a proxy through the same
## plumbing as a real card — while the WIDGET that draws it is a separate
## class (`ProxyFace`), for the same reason [DamageMarker] is not a
## [MiniCard]: there is no [CardInstance] behind it and most of what a
## small card can say about itself is a question you cannot ask.
##
## **IT IS NEVER REGISTERED.** Cached per name only so that repeated
## look-ups hand back the same object — [method CardArea._bind_cell]
## compares cell data by identity and would otherwise rebind every cell on
## every scroll.
static func data_for(card_name: String) -> CardData:
	if _data_cache.has(card_name):
		return _data_cache[card_name]
	var data := CardData.new(card_name, "", 0)
	data.oracle_text = RULES_TEXT
	_data_cache[card_name] = data
	return data


## name -> its [CardData]. Process-global like the registry itself, and
## deliberately NOT the registry: see the class doc's boundary rule 1.
static var _data_cache: Dictionary = {}


## Forget every proxy face built so far — the process-end companion of
## [method CardRegistry.unload], for the same reason: a [CardData] must
## not outlive the scripts it was built from.
static func unload() -> void:
	_data_cache.clear()


## Is [param data] one of ours? Asked by the deck-builder surfaces to
## decide which FACE to draw. It is a question about the object rather
## than about the name, because a cell holds the data it was bound with.
static func is_proxy_data(data: CardData) -> bool:
	return data != null and _data_cache.get(data.card_name, null) == data

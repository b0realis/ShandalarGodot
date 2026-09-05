class_name DeckModel
extends RefCounted
## THE DECK UNDER CONSTRUCTION — card counts, the 1997 rules that
## constrain them, the numbers the Stats window reads, and the deck text
## the builder saves. Everything the Deck Builder knows that is not a pixel.
##
## Shape: `name -> count`, the way a decklist is written, rather than
## [DeckList]'s expanded array (which is what the ENGINE wants at duel
## time). [method from_deck_list] folds one into the other and
## [method to_card_list] unfolds it back, so a deck saved here loads in the
## battle-setup screen and plays.
##
## Action methods follow the engine's own convention (CONTRIBUTING.md rule 3):
## they return "" on success or a human-readable refusal string, never an
## assert — a fifth Lightning Bolt is a player-level mistake, not a bug.
##
## THE RULES ARE THE ORIGINAL'S, and they are not the tournament rules a
## modern player expects. Two separate sets exist and the 1997 manual is
## explicit about which applies where:
##
## 1. The DECK BUILDER (this screen; manual ch.10 "Building Your Decks"):
##    *"in Shandalar, there are few restrictions on the contents of your
##    dueling deck. Any deck you can dream up, you can build and play"* and
##    *"you can construct as many decks as you care to, with few limits."*
##    The only hard limits are the ones the DUEL enforces on load, and the
##    string table spells both out: `@TOOFEWCARDS` and `@TOOMANYCARDS`.
## 2. SHANDALAR itself (the adventure, which we do not have yet) scales the
##    duplicate allowance by deck size — the manual's own table, kept here
##    as [method duplicates_allowed] and reported as an ADVISORY, never as
##    a refusal, because the Deck Builder never refused it.
##
## There is therefore NO four-of rule here. Saying "4 copies maximum" would
## be importing a tournament rule the 1997 game did not apply to this
## screen.
##
## ================================= THE SIDEBOARD =========================
##
## [member sideboard] is a SECOND pile, `name -> count` like the deck, and
## it is the `SB:` lines [DeckList] has always parsed. Two things about it
## are ours rather than 1997's, and both are marked where they are used:
##
##  * **The 1997 Deck Builder had no sideboard at all.** The word does not
##    occur anywhere in `shandalar-src/src/deck/deckdll.cpp`; its
##    `global_edited_deck` is one pile, and the `.dck` file's `.v<Colour>`
##    sections are the ADVENTURE AI's per-opponent-colour swaps, not a
##    tournament sideboard. So this whole surface is [QoL] — built because
##    `Side&board between duels` (`Program/Text.res:2863`) now reads the
##    field between the duels of a best-of-N match.
##  * **[constant SIDEBOARD_SIZE] is 15 by modern convention, NOT by 1997
##    rule.** Nothing in our code fixes a number: `MatchScreen`'s Sideboard
##    window only requires the DECK to go back in at the size it came out,
##    and [MatchState] has no sideboard field at all. Nothing in the 1997
##    sources fixes one either — the printed manual's only "sideboard" is
##    advice about your Shandalar collection (p.140). Fifteen is what
##    every modern constructed format uses, and it is stated as ADVICE
##    ([method sideboard_advice]), never as a refusal, exactly like
##    Shandalar's duplicate allowance.
##
## COPIES ARE COUNTED ACROSS BOTH PILES ([method copies_of]). A card in the
## sideboard is a copy of that card you are bringing to the duel — the
## match's sideboard step will move it into the deck — so four Lightning
## Bolt in the deck and one in the sideboard is five Lightning Bolt.
## [DeckFormat] counts the same way and for the same reason.
##
## ================================== [QoL] PROXIES ========================
##
## A PROXY ([ProxyCard]) IS AN ORDINARY ENTRY IN THESE TWO DICTIONARIES.
## It is a card name the [CardRegistry] does not know, held in
## [member counts] or [member sideboard] with a count like anything else,
## and that is the whole of its representation here — which is what makes
## an IMPORTED proxy and a DELIBERATELY ADDED one the same object rather
## than two code paths. [method add_proxy] is the deliberate door;
## [method DeckStore.import_file] is the imported one; both end in the
## same [method _put].
##
## Three consequences, each pinned by a test:
##   * EVERY COUNT RULE APPLIES TO IT. Shandalar's duplicate allowance
##     ([method extra_copies]) and [method DeckFormat.legal]'s four-of
##     both count proxies, because a proxy stands in for a card and a deck
##     built with stand-ins should still be a legal-looking deck.
##   * IT SAVES AND LOADS LIKE A CARD. No marker is written: the name goes
##     into the file verbatim and comes back a proxy for as long as the
##     registry does not know it. All three formats, main deck and
##     sideboard.
##   * IT CANNOT BE PLAYED. [method proxy_problem] is the sentence, and
##     the gates that show it are at the duel's own doors — see
##     [ProxyCard]'s class doc. This model refuses nothing for it: the
##     Deck Builder is a TOOL, and a deck full of proxies is exactly the
##     deck it exists to let you build.
##
## THE STATISTICS SIMPLY SKIP THEM. A proxy has no cost, no type and no
## colour to count, so the Stats window's matrix, the mana curve and the
## land ratio measure the cards that are really there — see [method _card],
## which is the quiet look-up they all go through.

# ------------------------------------------------ the 1997 hard limits --

## `@TOOFEWCARDS` (`s30/assets/text/Menus.txt:277`) — the duel's floor.
## Shandalar itself scales this by difficulty (manual ch.10: Apprentice 25,
## Magician 30, Sorcerer 35, Wizard 40, and *"the Shandalar Dueling
## Commission temporarily adds random basic lands"* below the line). The
## Deck Builder is not in Shandalar, so the Wizard number — the one the
## string table states — is the one this screen advises against.
const MIN_CARDS := 40
## `@TOOMANYCARDS` (`s30/assets/text/Menus.txt:281`), and the same limits
## again in `@GAUNTLETERRORS` (`Program/UIStrings.txt:1372`): *"Decks are
## limited to 200 unique cards / 500 total cards."* The audit pass split
## the citation — the UIStrings line is @GAUNTLETERRORS' and correct;
## @TOOMANYCARDS is in Menus.txt and was never in UIStrings.txt at all —
## and checked the wording against the 1997 copy, which carries a literal
## `\n` the Manalink copy dropped.
##
## (Grepping `Program/UIStrings.txt` needs `grep -a`. It is ISO-8859-1 and
## holds a 0xA9 byte, so GNU grep calls it binary and reports NOTHING —
## not even a count — without it. Every check behind this comment was run
## with `-a`.)
const MAX_UNIQUE := 200
const MAX_TOTAL := 500

## The string table's own words, quoted. `%s`-free so they can be shown
## verbatim; `docs/glossary-1997.md` is the rule that they must be.
const TOO_FEW_CARDS := "Your deck must have at least 40 cards to be used in the duel."
const TOO_MANY_CARDS := "Your deck has too many cards.\nThe duel allows 200 unique cards - 500 total. The extra cards in the deck will not be used."
const NAME_YOUR_DECK := "You must name your deck before saving."

## `@NEWDECK` — what an untitled deck is called. The manual: *"if you
## haven't given the deck a title, it's just called 'New Deck'"*.
const DEFAULT_NAME := "New Deck"

## [QoL] HOW BIG A SIDEBOARD SHOULD BE — fifteen cards, and the number is
## a MODERN-MAGIC CONVENTION rather than anything 1997 said. See the class
## doc for the search that found no rule: the 1997 Deck Builder had no
## sideboard, `MatchScreen` enforces only that the DECK goes back in at
## the size it came out, and `MatchState` never counts the pile. Stated as
## advice, never as a refusal — [method add_side] cannot fail on it.
const SIDEBOARD_SIZE := 15
## The advice that number produces. Ours, so it is written in our own
## voice and not dressed up as a quotation from the string table.
const SIDEBOARD_TOO_BIG := "Your sideboard has %d cards. Fifteen is the usual limit — that number is modern Magic's, not the 1997 game's."

## SHANDALAR's duplicate allowance by deck size (manual ch.10, "Deck
## Limitations"): `[max_total_cards, duplicates, with_the_Tome]`, where 0
## means no limit. *"This limitation does not apply to basic lands, of
## course, but to all other cards."* The Tome of Enlightenment is the
## World Magic that *"eases the limit on duplicate spells by one"*.
const DUPLICATE_TABLE := [
	[19, 1, 2],
	[39, 2, 3],
	[59, 3, 4],
	[0, 4, 0],       # 60 and up: four, or unlimited with the Tome
]

var deck_name := DEFAULT_NAME
## card name -> count. A name whose count reaches zero is REMOVED, so
## `counts.keys()` is exactly the deck's distinct cards.
var counts: Dictionary = {}
## [QoL] FREE TEXT SAVED WITH THE DECK — why these cards, what it is weak
## to, what to swap. The 1997 `@TITLEDIALOG` collected a Comments field
## (with Description, Name, E-Mail, Date, Face and Version beside it), so
## the idea is the era's; carrying it in the file is ours.
##
## It rides in the `.deck` file as `# note:` lines, which is the ONE shape
## that cannot break an existing file: [method DeckList.parse] already
## skips every line beginning with `#`, so a deck with notes loads in the
## battle-setup screen, in the converter and in any older build, and a
## deck WITHOUT notes reads back as "" rather than as an error.
## [method notes_from_text] is the reader.
var notes := ""
## [QoL] THE SIDEBOARD, `name -> count` like [member counts]. The `SB:`
## lines of the deck file; see the class doc for whose rules govern it.
var sideboard: Dictionary = {}
## The `# group:` declaration the loaded file carried, VERBATIM, or "".
##
## Carried, never authored. [DeckGroups] decides a deck's heading from its
## PATH for `User-created` and from this line for the rest, so a file
## cannot claim to be a 1997 original by writing one — and the Deck
## Builder offers no way to type it. What it must do is not DESTROY one:
## before the third audit pass (2026-09-01) [method to_text] dropped the
## line, so opening a shipped deck in the builder and saving it silently
## reclassified it. That is the only reason this field exists.
var group := ""


## Fold an expanded [DeckList] (what the loader and the engine use) into
## the builder's name->count shape.
static func from_deck_list(list: DeckList) -> DeckModel:
	var model := DeckModel.new()
	model.deck_name = list.deck_name if list.deck_name != "" else DEFAULT_NAME
	for card_name in list.cards:
		model.counts[card_name] = int(model.counts.get(card_name, 0)) + 1
	for card_name in list.sideboard:
		model.sideboard[card_name] = int(model.sideboard.get(card_name, 0)) + 1
	return model


func total() -> int:
	var sum := 0
	for card_name in counts:
		sum += int(counts[card_name])
	return sum


func unique() -> int:
	return counts.size()


func count_of(card_name: String) -> int:
	return int(counts.get(card_name, 0))


## THE QUIET REGISTRY LOOK-UP every statistic below goes through.
##
## [method CardRegistry.get_card] push_error()s on a name it does not know
## — right for a deck about to be played, wrong for a builder that
## deliberately holds PROXIES, where an unknown name is the feature. This
## asks [method CardRegistry.has_card] first and returns null instead, and
## every caller already had a `d == null` branch because a registry that
## lost a card would have hit it too.
static func _card(card_name: String) -> CardData:
	if not CardRegistry.has_card(card_name):
		return null
	return CardRegistry.get_card(card_name)


## Put one copy in the deck. "" on success, a refusal otherwise. The only
## refusals are the two the 1997 duel itself makes (see the class doc),
## plus the one this screen owes the player: a name that is not a card.
##
## [param allow_proxy] is what says *"I know this is not in the pool, put
## it in anyway"* — the deliberate stand-in ([method add_proxy]) and the
## importer both set it, and nothing else does, so a typo in a search box
## can never become a proxy by accident.
func add(card_name: String, allow_proxy := false) -> String:
	return _put(true, card_name, allow_proxy)


## [QoL] `Add proxy card` — the deliberate stand-in, for a card the player
## means to have later. The SAME entry as an imported one: one dictionary,
## one count, one code path.
func add_proxy(card_name: String) -> String:
	return _put(true, card_name, true)


## One copy into the deck ([param into_deck]) or the sideboard. Shared by
## [method add] and [method add_side] so the two piles cannot drift apart
## on what they will accept, and taking a BOOL rather than the dictionary
## itself because `==` on a Godot Dictionary compares CONTENTS, so an
## empty sideboard and an empty deck are the same object to it.
##
## Only the DECK is measured against the two 1997 limits: they are the
## duel's limits on the deck it is dealt, and counting the sideboard's own
## names toward [constant MAX_UNIQUE] would refuse a card for a reason the
## duel does not have.
func _put(into_deck: bool, card_name: String, allow_proxy: bool) -> String:
	if card_name.strip_edges() == "":
		return "A card needs a name"
	if not allow_proxy and not CardRegistry.has_card(card_name):
		return "'%s' is not in the card pool" % card_name
	if into_deck:
		if total() >= MAX_TOTAL:
			return TOO_MANY_CARDS
		if count_of(card_name) == 0 and unique() >= MAX_UNIQUE:
			return TOO_MANY_CARDS
		counts[card_name] = count_of(card_name) + 1
	else:
		sideboard[card_name] = side_count_of(card_name) + 1
	return ""


## Take one copy out. "" on success, a refusal otherwise.
func remove(card_name: String) -> String:
	var have := count_of(card_name)
	if have <= 0:
		return "There is no %s in this deck" % card_name
	if have == 1:
		counts.erase(card_name)
	else:
		counts[card_name] = have - 1
	return ""


## Take EVERY copy out — the whole column at once.
func remove_all(card_name: String) -> String:
	if count_of(card_name) <= 0:
		return "There is no %s in this deck" % card_name
	counts.erase(card_name)
	return ""


# ------------------------------------------------ [QoL] the sideboard --
# The second pile. Same shape and same action-method contract as the deck
# above; see the class doc for whose rules govern it and why it exists at
# all. Nothing here refuses on SIZE — [constant SIDEBOARD_SIZE] is advice.

func side_total() -> int:
	var sum := 0
	for card_name in sideboard:
		sum += int(sideboard[card_name])
	return sum


func side_count_of(card_name: String) -> int:
	return int(sideboard.get(card_name, 0))


## HOW MANY COPIES OF THIS CARD THE DECK BRINGS, deck and sideboard
## together. The match's sideboard step moves cards between the two piles,
## so a copy in either is a copy you are playing with — which is why every
## copy rule in this project counts them the same way ([DeckFormat.legal]).
func copies_of(card_name: String) -> int:
	return count_of(card_name) + side_count_of(card_name)


## Put one copy in the sideboard. Refuses only what [method add] refuses
## for a reason of its own: a card outside the pool. [param allow_proxy]
## means the same thing here as it does there.
func add_side(card_name: String, allow_proxy := false) -> String:
	return _put(false, card_name, allow_proxy)


## [QoL] The deliberate stand-in, straight into the sideboard.
func add_proxy_side(card_name: String) -> String:
	return _put(false, card_name, true)


func remove_side(card_name: String) -> String:
	var have := side_count_of(card_name)
	if have <= 0:
		return "There is no %s in the sideboard" % card_name
	if have == 1:
		sideboard.erase(card_name)
	else:
		sideboard[card_name] = have - 1
	return ""


func remove_all_side(card_name: String) -> String:
	if side_count_of(card_name) <= 0:
		return "There is no %s in the sideboard" % card_name
	sideboard.erase(card_name)
	return ""


## Move one copy out of the deck and into the sideboard. The pair below is
## what "cards move both ways" means; each is one action, so the screen
## can put one undo step around it.
##
## A PROXY CROSSES LIKE ANY OTHER CARD. Both methods pass
## [method ProxyCard.is_proxy] straight through as `allow_proxy`, so a
## card that was already in one pile is never refused by the other for
## being outside the pool — it plainly is, and moving it is not the moment
## to argue about that.
func to_sideboard(card_name: String) -> String:
	var refusal := remove(card_name)
	if refusal != "":
		return refusal
	return add_side(card_name, ProxyCard.is_proxy(card_name))


## ...and back. [method add]'s own refusals still apply — a deck already
## at [constant MAX_TOTAL] cannot take the card — and the copy stays in
## the sideboard when they do, so nothing is ever lost in transit.
func to_deck(card_name: String) -> String:
	if side_count_of(card_name) <= 0:
		return "There is no %s in the sideboard" % card_name
	var refusal := add(card_name, ProxyCard.is_proxy(card_name))
	if refusal != "":
		return refusal
	return remove_side(card_name)


## The sideboard expanded one entry per physical card — what
## `DuelConfig.sideboards` wants.
func to_side_list() -> Array[String]:
	var out: Array[String] = []
	for card_name in side_names():
		for _i in int(sideboard[card_name]):
			out.append(card_name)
	return out


## The sideboard in `S&ort deck` order, the same order [method names]
## puts the deck in.
func side_names() -> Array[String]:
	return _sorted_names(sideboard)


## `C&lear deck` — *"wipes the current deck from the Deck Builder. This
## only affects the deck you're working on; it does not affect any deck
## files."* The name resets too, so the cleared surface is a `New Deck`.
##
## The SIDEBOARD and the carried `# group:` line go with it: what is left
## has to be a new deck all through, or `Clear deck` would leave a
## fifteen-card sideboard attached to an empty deck and a heading claimed
## by a file the player has just wiped.
func clear() -> void:
	counts.clear()
	sideboard.clear()
	group = ""
	deck_name = DEFAULT_NAME


# ------------------------------------------------------------ legality --

## How many copies of one non-basic card SHANDALAR allows in a deck of
## [param deck_size] cards (manual ch.10). 0 = no limit.
static func duplicates_allowed(deck_size: int, with_tome := false) -> int:
	for row in DUPLICATE_TABLE:
		if row[0] == 0 or deck_size <= row[0]:
			return row[2] if with_tome else row[1]
	return 0


## True for a card the duplicate rule exempts — *"This limitation does not
## apply to basic lands, of course"*. A PROXY IS NOT EXEMPT: it stands in
## for a card, and a fifth copy of it is a fifth copy (see the class doc's
## proxy section, and [method DeckFormat.is_basic], which answers the same
## question the same way for the same reason).
static func exempt_from_duplicates(card_name: String) -> bool:
	var d := _card(card_name)
	return d != null and (d.supertypes & Mtg.Supertype.BASIC) != 0


# ------------------------------------------------------ [QoL] proxies --

## Every PROXY this deck holds, both piles, sorted — the names the player
## would have to replace before it could be duelled with. Empty for a deck
## made entirely of implemented cards, which is the ordinary case.
func proxy_names() -> Array[String]:
	return ProxyCard.names_in(counts.keys(), sideboard.keys())


func has_proxies() -> bool:
	for card_name in counts:
		if ProxyCard.is_proxy(card_name):
			return true
	for card_name in sideboard:
		if ProxyCard.is_proxy(card_name):
			return true
	return false


## WHY THIS DECK CANNOT BE DUELLED WITH, naming every proxy — or "" when
## it can. The sentence the Deck Builder's legality line leads with and
## the battle-setup screen refuses on ([method ProxyCard.refusal]).
##
## Deliberately NOT in [method problems]. That list is *"every reason the
## DUEL would reject this deck"* IN THE 1997 STRING TABLE'S OWN WORDS, and
## the original had no proxies and therefore no string for one — putting
## ours in a list of quotations would misattribute it, exactly as
## [method sideboard_advice] must stay out for the same reason.
func proxy_problem() -> String:
	return ProxyCard.refusal(proxy_names())


# --------------------------------------------- [QoL] the format analysis --

## WHAT THE TOURNAMENT RULES SAY ABOUT THIS DECK — every card over the
## four-of limit, every restricted card past its one copy, and every banned
## card, one line each ([method DeckFormat.offences]).
##
## It is a THIRD set of rules and the class doc's opening is still true of
## the first two: the 1997 Deck Builder enforced neither. This one is
## [DeckFormat]'s, i.e. the original SHELL's — the five radio buttons on
## the pre-duel screen — so it is a real rule of this game, just not one
## this screen has ever refused on. Like Shandalar's duplicate allowance
## and the sideboard's fifteen, it is stated as ADVICE and never as a
## refusal: a deck under construction breaks these rules most of the time,
## and a builder that would not save half-built work would be broken.
##
## Both piles, because the format check counts both (see
## [method DeckFormat.legal] for whose rule that is).
##
## Counted straight out of [member counts] and [member sideboard] rather
## than through [method to_card_list] — the legality line asks this on
## every card click, and expanding a 500-card deck into an array to count
## it back down again would undo the third audit pass's work on that path.
## O(distinct cards), like [method extra_copies] beside it.
func format_offences() -> Array[String]:
	var both := {}
	var side := {}
	for card_name in counts:
		if DeckFormat.is_basic(card_name):
			continue     # nothing checks a basic land
		both[card_name] = int(counts[card_name])
	for card_name in sideboard:
		if DeckFormat.is_basic(card_name):
			continue
		var copies := int(sideboard[card_name])
		side[card_name] = copies
		both[card_name] = int(both.get(card_name, 0)) + copies
	return DeckFormat.offences_of(both, side)


## What the original's Stats title bar would call this deck — one of the
## five formats ([method DeckFormat.classify]). The honest way to report a
## SINGLE restricted card, which [method format_offences] deliberately does
## not treat as a mistake: a lone Sol Ring is not an error, it is the
## difference between Tournament (Type 1.5) and Restricted (Type 1).
func deck_type() -> String:
	return DeckFormat.classify(to_card_list(), to_side_list())


## Every reason the DUEL would reject this deck, in the 1997 string
## table's own words. Empty = the deck can be played.
func problems() -> Array[String]:
	var found: Array[String] = []
	if total() < MIN_CARDS:
		found.append(TOO_FEW_CARDS)
	if total() > MAX_TOTAL or unique() > MAX_UNIQUE:
		found.append(TOO_MANY_CARDS)
	return found


func is_legal() -> bool:
	return problems().is_empty()


## [QoL] WHAT THE SCREEN SAYS ABOUT THE SIDEBOARD, in the same place and
## the same voice as Shandalar's duplicate advice — advice, not a refusal.
## Empty for a sideboard of fifteen or fewer, which includes the commonest
## case of all: no sideboard at all.
##
## It is deliberately NOT in [method problems]. That list is *"every reason
## the DUEL would reject this deck"* in the 1997 string table's own words,
## and the duel rejects nothing for this: `MatchScreen`'s Sideboard window
## has no size rule (it requires only that the deck go back in at the size
## it came out) and [MatchState] does not count the pile. Putting an
## invented limit in a list of quoted 1997 refusals would misattribute it.
func sideboard_advice() -> Array[String]:
	var found: Array[String] = []
	var have := side_total()
	if have > SIDEBOARD_SIZE:
		found.append(SIDEBOARD_TOO_BIG % have)
	return found


## Every card SHANDALAR would call an extra copy, as `name -> how many are
## over the limit`. `@EXTRACARDSDIALOG` is the 1997 dialog that acts on
## this list, and [method trim_duplicates] is its `Remove Extra Cards`.
##
## Walks [member counts] DIRECTLY. It used to walk [method names], which
## sorts, and sorting was 4.2 of the 4.4 ms this call cost on a 200-unique
## deck — paid on every card click, because [method DeckBuilderScreen.refresh]
## asks this question every time the deck moves.
##
## COPIES ARE COUNTED ACROSS BOTH PILES ([method copies_of]) and the
## ALLOWANCE is scaled by the MAIN deck's size, which is the split the two
## rules ask for: the manual's table is indexed by *"how many cards you
## have in your deck"*, and a sideboard card is still a copy of that card
## you brought. A card the sideboard alone pushes over the line is
## reported, and only its sideboard copies are cut ([method
## trim_duplicates]).
func extra_copies(with_tome := false) -> Dictionary:
	var over := {}
	var limit := duplicates_allowed(total(), with_tome)
	if limit <= 0:
		return over
	for card_name in counts:
		var have := copies_of(card_name)
		if have > limit and not exempt_from_duplicates(card_name):
			over[card_name] = have - limit
	for card_name in sideboard:
		if counts.has(card_name):
			continue        # already counted, both piles, above
		var have := side_count_of(card_name)
		if have > limit and not exempt_from_duplicates(card_name):
			over[card_name] = have - limit
	return over


## What SHANDALAR (not the Deck Builder) would say about this deck's
## duplicates — advice, never a refusal. `@EXTRACARDSDIALOG`'s own line
## heads the list: *"There are too many of the following Cards in your
## deck."*
func over_duplicate_limit(with_tome := false) -> Array[String]:
	var limit := duplicates_allowed(total(), with_tome)
	var over := extra_copies(with_tome)
	var found: Array[String] = []
	for card_name in over:
		var in_side := side_count_of(card_name)
		found.append("%d %s (Shandalar allows %d)%s" % [
			copies_of(card_name), card_name, limit,
			"" if in_side == 0 else " — %d in the sideboard" % in_side])
	found.sort()
	return found


## `Remove Extra Cards` (`@EXTRACARDSDIALOG`, `s30/assets/text/Menus.txt:38`)
## — cut every stack back to the allowance the same dialog reports. Returns
## how many physical cards went.
##
## The list is taken ONCE, against the deck as the dialog described it.
## Trimming shrinks the deck and the allowance is scaled by deck size, so
## re-reading it mid-loop would tighten the limit under its own feet and
## take more than the dialog said it would.
##
## THE SIDEBOARD IS CUT FIRST. The excess is counted across both piles
## ([method extra_copies]), and a card is in the sideboard precisely
## because the player decided it does not belong in the deck yet — taking
## the deck's copies while spares sit beside them would answer a question
## nobody asked. Only when the sideboard runs out does the deck lose any.
func trim_duplicates(with_tome := false) -> int:
	var over := extra_copies(with_tome)
	var removed := 0
	for card_name in over:
		var excess: int = int(over[card_name])
		var from_side: int = mini(excess, side_count_of(card_name))
		for _i in from_side:
			remove_side(card_name)
		var from_deck: int = excess - from_side
		if from_deck > 0:
			counts[card_name] = int(counts[card_name]) - from_deck
			if int(counts[card_name]) <= 0:
				counts.erase(card_name)
		removed += excess
	return removed


## Every copy of every card in [param colors] (a list of [enum Mtg.ManaColor]
## values, plus 0 for "artifact / colourless"). `Move by color out of deck`
## (`@DECKSURFACE_ADVENTURE`) is what asks for this; the count is what came
## out. A LAND is never taken: `@GROUPMOVE` offers no Land option and the
## manual is firm that lands have no colour.
func remove_by_color(colors: Array) -> int:
	var removed := 0
	for card_name in counts.keys():
		var d := _card(card_name)
		if d == null or d.is_land():
			continue
		var mask := d.color_mask()
		var hit := false
		for color in colors:
			if (int(color) == 0 and mask == 0) or (mask & int(color)):
				hit = true
				break
		if hit:
			removed += int(counts[card_name])
			counts.erase(card_name)
	return removed


# --------------------------------------------------------------- stats --
# The `Stats (%d cards)` window's own rows and columns (`@STATSSCREEN`,
# s30/assets/text/Menus.txt): a CARD TYPE x COLOUR matrix with a Total
# column and a Mana Sources row. Ported as pure queries so the window is a
# view and the tests read the numbers directly.

## `@STATSSCREEN` rows 10-17, minus `Interrupts`: our engine has no
## interrupt tier (docs/glossary-1997.md §5 — *"no modern rules object
## corresponds… using the word would promise timing we do not
## implement"*), and every 1997 interrupt in our pool is registered as an
## Instant, so the row would read 0 and lie about the era.
const STAT_ROWS: Array = [
	["Creatures", Mtg.CardType.CREATURE],
	["Enchantments", Mtg.CardType.ENCHANTMENT],
	["Sorceries", Mtg.CardType.SORCERY],
	["Instants", Mtg.CardType.INSTANT],
	["Land", Mtg.CardType.LAND],
	["Artifacts", Mtg.CardType.ARTIFACT],
]

## `@STATSSCREEN` columns 2-8, in the original's own order (alphabetical
## by colour name, which is how the 1997 window lists them).
const STAT_COLUMNS: Array = [
	["Black", Mtg.ManaColor.B],
	["Blue", Mtg.ManaColor.U],
	["Green", Mtg.ManaColor.G],
	["Red", Mtg.ManaColor.R],
	["White", Mtg.ManaColor.W],
	["Colorless", 0],
]


## Cards of one type in one colour. [param color] 0 means COLORLESS —
## the manual: *"Land cards do not have a color; they're colorless."*
func type_color_count(type_flag: int, color: int) -> int:
	var sum := 0
	for card_name in counts:
		var d := _card(card_name)
		if d == null or not (d.types & type_flag):
			continue
		var mask := d.color_mask()
		var hit: bool = (mask == 0) if color == 0 else bool(mask & color)
		if hit:
			sum += int(counts[card_name])
	return sum


## THE WHOLE `@STATSSCREEN` MATRIX IN ONE WALK — `matrix[row][column]` in
## [constant STAT_ROWS] x [constant STAT_COLUMNS] order, and the same
## numbers [method type_color_count] gives cell by cell.
##
## The Stats window asked for all thirty-six cells one at a time, and each
## call walked the deck and looked every card up in the registry: 3.5 ms of
## a 12.6 ms window on a 500-card deck (third audit pass, 2026-09-01). One
## walk is 0.15 ms. A card in two columns (a gold card) or two rows (an
## artifact creature) still counts in both, exactly as the 1997 matrix
## does — which is why a row does not add up to the deck size.
func type_color_matrix() -> Array:
	var matrix: Array = []
	for _row in STAT_ROWS:
		var line: Array[int] = []
		line.resize(STAT_COLUMNS.size())
		line.fill(0)
		matrix.append(line)
	for card_name in counts:
		var d := _card(card_name)
		if d == null:
			continue
		var have := int(counts[card_name])
		var mask := d.color_mask()
		for r in STAT_ROWS.size():
			if not (d.types & int(STAT_ROWS[r][1])):
				continue
			var line: Array = matrix[r]
			for c in STAT_COLUMNS.size():
				var color := int(STAT_COLUMNS[c][1])
				if (mask == 0) if color == 0 else bool(mask & color):
					line[c] += have
	return matrix


## `Mana Sources` — every card that can PRODUCE the colour, which is the
## row that tells you whether the deck can cast itself.
func mana_sources() -> Dictionary:
	var tally := {}
	for color in Mtg.WUBRG:
		tally[color] = 0
	tally[0] = 0
	for card_name in counts:
		var d := _card(card_name)
		if d == null:
			continue
		var produced := MiniCard.mana_colors(d)
		if produced.is_empty():
			continue
		var colorless_only := true
		for color in produced:
			if tally.has(color):
				tally[color] += int(counts[card_name])
				colorless_only = false
		if colorless_only:
			tally[0] += int(counts[card_name])
	return tally


## `Non-Creature` — the `@STATSSCREEN` row that is everything but a
## creature (lands included, as the original counts it).
func non_creature_count() -> int:
	return total() - creature_count()


## Cards per mana value, buckets 0..7 where 7 means "7 or more". The one
## stat that is s30's rather than 1997's (`drawDeckStats`,
## edit_deck.go:1006 `cmcCounts := make([]int, 8) // CMC 0 through 7+`) —
## kept because a mana curve is the single most useful thing a deck
## builder can draw, and the original's Stats window has no equivalent.
func mana_curve() -> Array[int]:
	var curve: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	for card_name in counts:
		var d := _card(card_name)
		if d == null or d.is_land():
			continue      # a land has no cost to curve
		curve[mini(d.cost.mana_value(), 7)] += int(counts[card_name])
	return curve


## Cards of each colour (a gold card counts once per colour, as s30 does).
func color_counts() -> Dictionary:
	var tally := {}
	for color in Mtg.WUBRG:
		tally[color] = 0
	for card_name in counts:
		var d := _card(card_name)
		if d == null:
			continue
		var mask := d.color_mask()
		for color in Mtg.WUBRG:
			if mask & color:
				tally[color] += int(counts[card_name])
	return tally


# ------------------------------------------- [QoL] the extended stats --
# The 1997 Stats window is a Card Type x colour MATRIX of numbers, and a
# matrix answers "what is in here" without answering "is this deck going
# to work". These four queries are what the Stats window graphs on top of
# it. All of them are pure, so the window stays a view and the tests read
# the numbers rather than the pixels (tests/ui/test_deck_model.gd).

## Mean mana value over the SPELLS — lands excluded, because a land has no
## cost and averaging it in drags the number toward zero and hides the
## thing the average is for. 0.0 for a deck with no spells.
func average_cost() -> float:
	var spells := 0
	var total_cost := 0
	for card_name in counts:
		var d := _card(card_name)
		if d == null or d.is_land():
			continue
		spells += int(counts[card_name])
		total_cost += d.cost.mana_value() * int(counts[card_name])
	return 0.0 if spells == 0 else float(total_cost) / float(spells)


## Cards of each `Mtg.CardType` in [constant STAT_ROWS] order. A card with
## two types (an artifact creature) counts in BOTH, which is what the
## 1997 matrix does too — its row totals do not add up to the deck size
## either, and pretending otherwise would misreport artifact creatures.
func type_counts() -> Dictionary:
	var tally := {}
	for row in STAT_ROWS:
		tally[int(row[1])] = 0
	for card_name in counts:
		var d := _card(card_name)
		if d == null:
			continue
		var have := int(counts[card_name])
		for row in STAT_ROWS:
			if d.types & int(row[1]):
				tally[int(row[1])] += have
	return tally


## What share of the deck is land, as a fraction. The single number a
## builder checks most often; a 40-card deck wants somewhere near 0.4.
func land_ratio() -> float:
	return 0.0 if total() == 0 else float(land_count()) / float(total())


func land_count() -> int:
	return _type_total(Mtg.CardType.LAND)


func creature_count() -> int:
	var sum := 0
	for card_name in counts:
		var d := _card(card_name)
		if d != null and d.is_creature() and not d.is_land():
			sum += int(counts[card_name])
	return sum


## Everything that is neither a land nor a creature — s30's `default`
## bucket in the same switch (edit_deck.go:989-996).
func spell_count() -> int:
	return total() - land_count() - creature_count()


## THE FOUR NUMBERS THE SCREEN LETTERS ON EVERY CARD CLICK — total, land,
## creature and spell — in ONE walk of [member counts].
##
## [method DeckBuilderScreen.refresh] used to ask for them separately, and
## `spell_count()` is `total - land - creature`, so a 200-unique deck was
## walked FIVE times and looked every card up in the registry three times
## over. Measured at 0.46 ms of a 1.01 ms card click (third audit pass,
## 2026-09-01); one walk is 0.11 ms. Keys: `total`, `land`, `creature`,
## `spell`.
func headline_counts() -> Dictionary:
	var total_cards := 0
	var land := 0
	var creature := 0
	for card_name in counts:
		var have := int(counts[card_name])
		total_cards += have
		var d := _card(card_name)
		if d == null:
			continue
		if d.types & Mtg.CardType.LAND:
			land += have
		elif d.is_creature():
			creature += have
	return {
		"total": total_cards, "land": land, "creature": creature,
		"spell": total_cards - land - creature,
	}


func _type_total(type_flag: int) -> int:
	var sum := 0
	for card_name in counts:
		var d := _card(card_name)
		if d != null and (d.types & type_flag):
			sum += int(counts[card_name])
	return sum


# ----------------------------------------------------------- the output --

## `S&ort deck` order, and it is the ORIGINAL's, not a decklist's: *"Sort
## Deck rearranges the cards in order by color, putting like cards
## together. **Lands are always at the beginning.**"* (manual ch.10).
## Colour order is WUBRG, then gold, then colourless, then name.
##
## The rank is computed ONCE PER CARD and sorted alongside the name, not
## inside the comparator: 200 unique cards is ~1500 comparisons and the
## comparator did two registry look-ups in each of them, which measured
## 4.2 ms — the largest single cost of a card click, since
## [method DeckBuilderScreen.refresh] runs on every one. Decorated, the
## same call is 0.3 ms. ([method DeckFilter.apply] already sorts this way.)
func names() -> Array[String]:
	return _sorted_names(counts)


## One pile's names in `S&ort deck` order. Shared by [method names] and
## [method side_names] so the deck area, the sideboard area and the saved
## file are all in the same order.
static func _sorted_names(pile: Dictionary) -> Array[String]:
	var keyed: Array = []
	keyed.resize(pile.size())
	var i := 0
	for card_name in pile:
		keyed[i] = [_sort_rank(card_name), card_name]
		i += 1
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var out: Array[String] = []
	out.resize(keyed.size())
	for j in keyed.size():
		out[j] = keyed[j][1]
	return out


## Lands sort before everything (rank -1); the rest by DeckFilter's WUBRG
## colour rank, so the builder's columns and its saved file agree.
##
## A PROXY SORTS LAST (rank 99), which is not a fallback but the right
## answer: a proxy has no colour to claim, so there is no column in
## `S&ort deck`'s colour order it belongs in — and the cards a player still
## has to replace gathered at the end of the deck area is where they are
## easiest to find.
static func _sort_rank(card_name: String) -> int:
	var d := _card(card_name)
	if d == null:
		return 99
	if d.is_land():
		return -1
	return DeckFilter.color_rank(d)


## The deck as this project's `.deck` text — the format `DeckList.parse`
## reads, so the file the builder writes is one the battle-setup screen
## loads (tests/ui/test_deck_model.gd pins the round trip).
##
## DEVIATION, deliberate: the original saved `.dck` (*"must have a .dck
## extension to be recognized"*). We write the project's own `.deck`,
## which is human-readable, round-trips losslessly and is what
## `game/setup_screen.gd` already scans; `tools/deck_convert.gd` converts
## either way for anyone who wants the 1997 file.
##
## EVERY FIELD THE FILE CARRIES IS WRITTEN BACK, and until the third audit
## pass (2026-09-01) two of them were not. This method wrote the banner,
## `name:`, the `# note:` lines and the counts — no `SB:` lines and no
## `# group:` — while [DeckList] parsed both. Opening a deck that had
## either and saving it therefore DESTROYED it silently, and both fields
## had just become live: `Side&board between duels` plays the sideboard
## and the five shipped decks were given real fifteen-card ones, and
## `# group:` decides the heading a deck files under in the battle-setup
## list. `tests/ui/test_deck_model.gd` now round-trips a shipped deck
## field by field, which is the only shape of test that catches the NEXT
## field somebody adds.
func to_text() -> String:
	var lines := PackedStringArray()
	lines.append("# Built in the Deck Builder.")
	# Carried, never authored — see [member group]. It goes above `name:`
	# because that is where the shipped decks put it and because
	# [method DeckGroups.declared_in] takes the FIRST declaration it finds.
	if group.strip_edges() != "":
		lines.append("%s %s" % [DeckGroups.PREFIX, group.strip_edges()])
	lines.append("name: %s" % deck_name)
	for line in notes.strip_edges().split("\n"):
		if line.strip_edges() != "":
			lines.append("# note: %s" % line.strip_edges())
	for card_name in names():
		lines.append("%d %s" % [int(counts[card_name]), card_name])
	if not sideboard.is_empty():
		lines.append("")
		for card_name in side_names():
			lines.append("SB: %d %s" % [int(sideboard[card_name]), card_name])
	return "\n".join(lines) + "\n"


## [QoL] Read [member notes] back out of a `.deck` file's raw text. A file
## written before notes existed has no `# note:` lines and yields "" —
## which is why this can never make an old deck fail to load.
static func notes_from_text(text: String) -> String:
	var found := PackedStringArray()
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("# note:"):
			found.append(line.substr(7).strip_edges())
	return "\n".join(found)


# ---------------------------------------------------------- the exports --
# [QoL] TWO EXPORT FORMATS, chosen so the pair covers both directions a
# deck can travel out of this project:
#
#   .dec  the community (Dojo / Apprentice) decklist — bare `4 Card Name`
#         lines with a `// NAME :` header. It is the lingua franca every
#         modern tool reads (Magic Workstation, Cockatrice, Moxfield,
#         Arena's importer all take it), and it is the format a player
#         pastes a deck INTO a forum post as. Nothing is lost: our own
#         `.deck` is a superset of it, so a `.dec` we write loads straight
#         back in.
#   .dck  the ORIGINAL MicroProse 1997 format — `.id TAB count TAB name`.
#         It is the one format the 1997 game itself can open, so a deck
#         built here can be dropped into a real Shandalar install's Decks
#         folder. `tools/deck_convert.gd` already reads and writes it from
#         the command line; this is the same emitter behind a button.
#
# `.deck` is not on the list because Save already writes it — an "export"
# that produced the file you just saved would be a menu entry that does
# nothing. tests/ui/test_deck_model.gd round-trips both.

## The deck as a portable community decklist.
func to_dec_text() -> String:
	var lines := PackedStringArray()
	lines.append("// NAME : %s" % deck_name)
	for line in notes.strip_edges().split("\n"):
		if line.strip_edges() != "":
			lines.append("// %s" % line.strip_edges())
	for card_name in names():
		lines.append("%d %s" % [int(counts[card_name]), card_name])
	# `SB:` is Apprentice's own sideboard line and the reason [DeckList]
	# accepts it at all — an exported `.dec` that dropped the sideboard
	# would lose in the community format exactly what the third audit pass
	# stopped `.deck` losing.
	for card_name in side_names():
		lines.append("SB: %d %s" % [int(sideboard[card_name]), card_name])
	return "\n".join(lines) + "\n"


## The deck in the 1997 file format. [param ids] is card name -> the
## original's numeric id (`cards/data/dck_ids.txt`); a card with no known
## id is emitted as `.0`, exactly as tools/deck_convert.gd emits it, which
## the original's own loader tolerates because names are authoritative.
func to_dck_text(ids: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append(deck_name)
	lines.append("")
	for card_name in names():
		lines.append(".%d\t%d\t%s" % [
			int(ids.get(card_name, 0)), int(counts[card_name]), card_name])
	# The 1997 file's sideboard is FIVE per-opponent-colour sections plus
	# `.vNone` ([method DeckList.parse_dck]), which the original's AI used
	# to swap against the colour it was facing. We hold ONE sideboard, so
	# it goes under `.vNone` — the section that names no opponent colour —
	# and `parse_dck` folds the sections by max-per-name, so reading our
	# file back gives the pile we wrote.
	if not sideboard.is_empty():
		lines.append(".vNone")
		for card_name in side_names():
			lines.append(".%d\t%d\t%s" % [
				int(ids.get(card_name, 0)), int(sideboard[card_name]), card_name])
	return "\n".join(lines) + "\n"


## The deck expanded one entry per physical card — what DuelConfig wants.
func to_card_list() -> Array[String]:
	var out: Array[String] = []
	for card_name in names():
		for _i in int(counts[card_name]):
			out.append(card_name)
	return out


## A DEEP-ENOUGH COPY OF EVERY FIELD. This is what UNDO, `Copy deck to`
## and `Clear deck`/`Restore deck` keep, so a field missing here is a
## field the player loses by pressing Undo — which is how the sideboard
## and the carried `# group:` line had to be added the moment they existed.
func duplicate_model() -> DeckModel:
	var copy := DeckModel.new()
	copy.deck_name = deck_name
	copy.counts = counts.duplicate()
	copy.sideboard = sideboard.duplicate()
	copy.notes = notes
	copy.group = group
	return copy


func _to_string() -> String:
	if sideboard.is_empty():
		return "%s (%d cards)" % [deck_name, total()]
	return "%s (%d + %d sideboard)" % [deck_name, total(), side_total()]

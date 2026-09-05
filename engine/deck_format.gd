class_name DeckFormat
extends RefCounted
## THE FIVE FORMATS — `Unrestricted` / `Wild` / `Restricted (Type 1)` /
## `Tournament (Type 1.5)` / `Highlander`, the five radio buttons at the
## top of the original's pre-duel parameter screen
## (`@SHELLPAGE_MULTIDUEL`, `Program/Text.res:2854-2859`; the same five,
## spelled without the parentheses, are `@DECKTYPES` at `:890`).
##
## ================================ WHERE THE RULES COME FROM =============
##
## **Not from the manual, and not from `Duel.hlp`.** Both were searched
## end to end: the 220-page manual never uses the words "Unrestricted",
## "Highlander" or "Type 1.5" at all, its only "Type I" is one aside on
## p.134, and its "Restricted" is a DIFFERENT THING — a Deck Builder card
## filter for *"the special, valuable cards from other sets that appear in
## Shandalar as treasures"* (p.147, and the Glossary at p.180 gives that as
## sense (1), calling the format meaning sense (2) and leaving it vague).
## `Duel.hlp` has no format topic. This is a shell feature, and the shell
## was never documented for players.
##
## The rules come from the game's OWN CODE — `check_deck_type()` in
## `shandalar-src/src/deck/deckdll.cpp:2908-2954`, whose five branches are
## reproduced below one for one — corroborated by the MicroProse ManaLink
## 1.3 readme (`shandalar-src/Readme13.txt:142-144`), which is the only
## prose anywhere that names the five together: *"The Deck Builder displays
## your deck name and deck type (Unrestricted, Wild, Restricted,
## Tournament or Highlander) in the title bar when you click the Stats
## button."*
##
## ONE THING THE SOURCES DO NOT SETTLE, stated plainly because a help page
## depends on it: the original CLASSIFIES a deck with this algorithm and
## prints the answer, and nothing in any available source shows the radio
## group being ENFORCED when a match starts (that code is inside
## `Magic.exe`, for which only a function-name trace survives). Turning the
## classifier into a legality check is therefore OURS. It is the only
## reading under which the radio group means anything, and each format's
## test below is exactly the branch `check_deck_type()` uses to file a
## deck under that name.
##
## ============================== THE LISTS, AND THEIR AGE ================
##
## [constant RESTRICTED] and [constant BANNED] began as `restrictions[]`,
## `deckdll.cpp:640-737`. **That is the Manalink project's table, not
## MicroProse's 1997 one** — it contains cards printed a decade after the
## game (Treasure Cruise, Dig Through Time, the Conspiracy cards) and is,
## in substance, the MODERN VINTAGE list.
##
## **THE ARGUMENT THAT USED TO JUSTIFY LEAVING IT AT THAT WAS WRONG, and
## it is corrected here rather than quietly deleted** (2026-09-01). It ran:
## *"the anachronism costs nothing, because a card can only matter if it is
## in a deck and a deck can only hold cards we have implemented — so what
## survives the intersection is exactly the era's list."* It is sound in
## ONE direction only. A card ADDED to the list after 1997 is outside our
## 2ed/4ed/arn/atq/leg/drk/past/phpr pool, so it never matches and costs
## nothing — true. But a card REMOVED from the list since 1997 **is** in
## our pool and was silently going unflagged, and there were eleven of
## them. The intersection filters the additions; it cannot restore the
## removals.
##
## THE ERA-CORRECT LIST, AND WHERE IT COMES FROM. Still no 1997 list
## survives in any file this project can read, and the search for one was
## finished on 2026-09-01 — do not repeat it:
##   * `Rarity.csv`'s `Rarity` column was READ, not assumed: its values
##     are print rarities and print-run counts (`C`/`U`/`R`, `U1`, `C3`,
##     `3E`, `L8`) across all 1001 rows. No legality value anywhere. The
##     old claim that it "encodes set rarity, not legality" is confirmed.
##   * The 1997 game DID know the distinction — `@RARITY`
##     (`s30/assets/text/Menus.txt:384`) offers five filter values,
##     `&Common &Uncommon &Rare R&estricted &Banned`, and `@RESTRICTED`
##     (`Program/CueCards.txt:81`) letters *"Restricted cards are in the
##     list"*. So the data existed; it lives inside `Rarity.dat`, a 943 KB
##     undecoded binary whose Manalink copy differs from the `Program/`
##     one, and/or inside `Deckdll.dll`. Decoding it is the one job that
##     could recover MicroProse's OWN list, and Provenance.md's Tier 2
##     decompilation is the other place to look.
## Until then the era list comes from the DCI's own published one: **_The
## Duelist_ #22 (1 January 1998), "Banned and Restricted"** — the Classic
## (Type 1) restricted list as printed, twenty-five cards. That is a
## contemporaneous printed source about PAPER Magic, so it ranks with the
## 1998 Advanced Strategy Guide rather than with the game's own artefacts;
## it is cited on every card it put here.
##
## WHAT THE LIST IS NOW: **the union of the two.** The modern Manalink
## table is kept whole, by NAME, so a card graduating into the pool later
## becomes restricted at that moment rather than being quietly legal — that
## half of the old argument still holds. The era entries are added beside
## it and marked. Nothing was REMOVED, and three modern entries that ARE in
## our pool and are NOT on the 1998 list (Mana Crypt, Mana Vault, Time
## Vault) are left standing and recorded in `docs/ROADMAP.md` for the owner
## to rule on: removing a restriction loosens the rules, which is not a
## change to make on a secondary source's say-so.

## `Text.res:2854-2859`, verbatim and in the original's own order — which
## is also, not by accident, loosest first.
const UNRESTRICTED := "Unrestricted"
const WILD := "Wild"
const RESTRICTED_T1 := "Restricted (Type 1)"
const TOURNAMENT_T15 := "Tournament (Type 1.5)"
const HIGHLANDER := "Highlander"
const ORDER: Array[String] = [UNRESTRICTED, WILD, RESTRICTED_T1,
	TOURNAMENT_T15, HIGHLANDER]

## The copy limit every format but [constant UNRESTRICTED] enforces —
## `deckdll.cpp:2939` (`if (num > 4)`). Basic lands are exempt
## (`check_basic()`, `:2881-2902`), which is also the printed manual's
## rule for Shandalar decks (p.139: *"This limitation does not apply to
## basic lands, of course, but to all other cards"*).
const COPY_LIMIT := 4

## At most one copy in [constant RESTRICTED_T1], none at all in
## [constant TOURNAMENT_T15]. The union of the two lists described in the
## class doc; names outside our card pool simply never turn up in a deck.
const RESTRICTED: Array[String] = [
	# ------------------------------------------------------------------
	# `restrictions[]` flagged `RST_RESTRICTED` (`deckdll.cpp:640-737`) —
	# the MODERN Vintage list, kept whole so a card graduating into the
	# pool arrives already restricted. Every name here that our pool does
	# contain is also on the 1998 list below, EXCEPT the three marked.
	"Ancestral Recall", "Balance", "Black Lotus", "Brainstorm",
	"Chalice of the Void", "Channel", "Demonic Consultation",
	"Demonic Tutor", "Dig Through Time", "Fastbond", "Flash",
	"Imperial Seal", "Library of Alexandria", "Lion's Eye Diamond",
	"Lodestone Golem", "Lotus Petal",
	"Mana Crypt",       # in our pool; NOT on the 1998 list — see the class doc
	"Mana Vault",       # in our pool; NOT on the 1998 list — see the class doc
	"Memory Jar", "Merchant Scroll", "Mind's Desire", "Mox Emerald",
	"Mox Jet", "Mox Pearl", "Mox Ruby", "Mox Sapphire", "Mystical Tutor",
	"Necropotence", "Ponder", "Sol Ring",
	# Strip Mine really is era-correct, and the date is the reason it looks
	# absent below: the DCI announced it on 3 December 1997 EFFECTIVE
	# 1 January 1998, and _The Duelist_ #22 went to press with the old list.
	"Strip Mine",
	"Time Vault",       # in our pool; NOT on the 1998 list — see the class doc
	"Time Walk", "Timetwister", "Tinker", "Tolarian Academy",
	"Treasure Cruise", "Trinisphere", "Vampiric Tutor",
	"Wheel of Fortune", "Windfall", "Yawgmoth's Bargain",
	"Yawgmoth's Will",
	# ------------------------------------------------------------------
	# ERA-CORRECT, added 2026-09-01. Every one of these is on the DCI's
	# Classic (Type 1) restricted list as printed in _The Duelist_ #22
	# (1 January 1998), is in our card pool RIGHT NOW, and was going
	# unflagged — the hole in the intersection argument, in the flesh. All
	# eleven have since been unrestricted in Vintage, which is exactly why
	# the modern table above does not carry them (Braingeyser 2004, Recall
	# 2003, Black Vise and Mind Twist 2007, Regrowth 2013, the rest
	# earlier).
	"Berserk", "Black Vise", "Braingeyser", "Fork", "Ivory Tower",
	"Maze of Ith", "Mirror Universe", "Recall", "Regrowth",
	"Underworld Dreams",
	# The owner named this one, and it is the one entry where the period
	# source is STRICTER than what we do: _The Duelist_ #22 has Mind Twist
	# on the Classic BANNED list, not the restricted one (it was banned on
	# 1 February 1996 and unrestricted only in 2007). Restricting it is the
	# owner's instruction and the conservative half of that reading — it
	# can only make an illegal deck illegal, never a banned one legal —
	# and the discrepancy is logged in `docs/ROADMAP.md` rather than
	# resolved here, because [constant BANNED] is not this pass's to widen.
	"Mind Twist",
]

## `RST_BANNED` — illegal in everything but [constant UNRESTRICTED]. The
## first nine are the ANTE cards, which the table flags `RST_ANTE |
## RST_BANNED` together; the three after them are the dexterity cards and
## the sub-game. (The thirteen Conspiracy cards in the same table are
## omitted: they are not Magic cards a deck can hold, and no set this
## project reads contains one.)
##
## THIS LIST IS NOT ERA-CORRECT EITHER, and the direction of the error is
## the opposite of [constant RESTRICTED]'s: _The Duelist_ #22's Classic
## (Type 1) BANNED list also carries **Channel**, **Divine Intervention**
## and **Mind Twist**, and all three are in our pool. They are NOT added
## here — widening a ban is a real rules change and the owner's brief for
## this pass was explicit that *"Banned is fine as it stands"* — but the
## finding is recorded in `docs/ROADMAP.md` so the decision is his and not
## an oversight. (Channel is on our RESTRICTED list, which is the looser
## of the two readings; Mind Twist has just been put there for the same
## reason.)
const BANNED: Array[String] = [
	"Amulet of Quoz", "Bronze Tablet", "Contract from Below", "Darkpact",
	"Demonic Attorney", "Jeweled Bird", "Rebirth", "Tempest Efreet",
	"Timmerian Fiends",
	"Chaos Orb", "Falling Star", "Shahrazad",
]


## Is [param card_name] exempt from every copy limit? `check_basic()`
## (`deckdll.cpp:2881-2902`) exempts the basic lands; the snow basics,
## Wastes, Relentless Rats and Shadowborn Apostle it also names are
## Manalink-era cards that no set this project reads contains, so the
## supertype IS the whole rule here.
##
## A PROXY IS NOT BASIC, and asking quietly is the point: a proxy is a
## name the registry does not know ([ProxyCard]), and
## [method CardRegistry.get_card] push_error()s on one — right for a deck
## about to be played, wrong for a deck being BUILT out of stand-ins,
## which is a deck this function is asked about on every card click. The
## answer is the same either way (not basic, so every copy rule applies to
## it), and see [method legal] for why that answer is the one we want.
static func is_basic(card_name: String) -> bool:
	if not CardRegistry.has_card(card_name):
		return false
	var data := CardRegistry.get_card(card_name)
	return data != null and (data.supertypes & Mtg.Supertype.BASIC) != 0


## card name -> copies, ignoring basic lands (nothing checks them).
static func nonbasic_counts(cards: Array) -> Dictionary:
	var counts := {}
	for card_name in cards:
		if is_basic(String(card_name)):
			continue
		counts[card_name] = int(counts.get(card_name, 0)) + 1
	return counts


## May [param cards] be played in [param format]? Returns "" when it may,
## or the reason it may not — this project's action-method convention, so
## the setup screen and the Deck Builder can both simply show the string.
##
## THE SIDEBOARD IS PART OF THE DECK FOR EVERY TEST HERE, and until
## 2026-09-01 it was not looked at at all. `legal()` took one array, every
## caller passed `DeckList.cards`, and so a `Restricted (Type 1)` deck
## could carry four Black Lotus in its `SB:` lines and pass — in the
## battle-setup screen, in the Deck Lab's `--format` flag, everywhere. The
## hole was invisible while nothing read `SB:`; `Side&board between duels`
## reads it now and swaps those cards INTO the deck between the duels of a
## match, so a format check that ignores the sideboard is checking a deck
## the player is not going to play.
##
## WHOSE RULE THIS IS. Not 1997's: the original's classifier
## (`check_deck_type()`, `deckdll.cpp:2908`) walks `global_edited_deck`,
## one pile, because the 1997 standalone Deck Builder had no sideboard to
## walk — the word does not appear anywhere in `deckdll.cpp`, and the
## `.dck` file's `.v<Colour>` sections are the adventure AI's
## per-opponent-colour swaps rather than a tournament sideboard. Counting
## the two piles together is the MODERN convention (a constructed deck and
## its sideboard share the four-of limit), adopted here because our duel
## really does move cards between them. [param sideboard] defaults to
## empty, so a caller that has no sideboard is checked exactly as before.
##
## PROXIES ARE COUNTED LIKE ANY OTHER CARD, and that is a decision rather
## than an accident (2026-09-01, the proxy pass). A proxy ([ProxyCard]) is
## a stand-in for a card, so a deck built out of stand-ins should still be
## a LEGAL-LOOKING deck — five proxy Shivan Dragon breaks the four-of rule
## exactly as five real ones would, and the player finds that out while
## they are still building rather than on the day the card graduates and
## the deck stops being legal. Two consequences worth stating:
##   * a proxy is never [method is_basic], so no copy limit exempts it;
##   * a proxy whose NAME is on [constant BANNED] or [constant RESTRICTED]
##     is treated as that card — a proxy Black Lotus is restricted. The
##     lists are kept by name precisely so a card outside the pool is
##     already on them when it arrives, and a proxy IS a card outside the
##     pool, so this needed no new code at all.
## None of this lets a proxy deck be PLAYED — that gate is
## [method ProxyCard.refusal_for], and it comes first at every door.
##
## The five tests are `check_deck_type()`'s five branches, read as rules
## rather than as labels:
##
##   * **Unrestricted** — the catch-all the classifier falls back to when
##     a deck breaks every other rule. Nothing is illegal.
##   * **Wild** — no banned card, at most four copies of anything. (The
##     classifier reaches WILD when a RESTRICTED card appears more than
##     once, i.e. when the restricted list is ignored but the copy limit
##     is not.)
##   * **Restricted (Type 1)** — Wild, and restricted cards singleton.
##   * **Tournament (Type 1.5)** — Restricted (Type 1), and no restricted
##     card at all.
##   * **Highlander** — no non-basic card twice. Checked FIRST in the
##     original and returned from immediately, which is why it is a rule
##     of its own and owes nothing to either list.
static func legal(cards: Array, format: String, sideboard: Array = []) -> String:
	if format == UNRESTRICTED:
		return ""
	var counts := nonbasic_counts(both_piles(cards, sideboard))
	var side := nonbasic_counts(sideboard)
	if format == HIGHLANDER:
		for card_name in counts:
			if counts[card_name] > 1:
				return "%s: %s" % [format, SINGLETON_LINE % [
					card_name, counts[card_name], _where(side, card_name)]]
		return ""
	for card_name in counts:
		var copies: int = counts[card_name]
		if BANNED.has(card_name):
			return "%s: %s" % [format,
				BANNED_LINE % [card_name, _where(side, card_name)]]
		if copies > COPY_LIMIT:
			return "%s: %s" % [format, OVER_COPIES % [
				copies, card_name, _where(side, card_name), COPY_LIMIT]]
		if not RESTRICTED.has(card_name):
			continue
		if format == TOURNAMENT_T15:
			return "%s: %s" % [format,
				BARS_RESTRICTED % [card_name, _where(side, card_name)]]
		if format == RESTRICTED_T1 and copies > 1:
			return "%s: %s" % [format, OVER_RESTRICTED % [
				copies, card_name, _where(side, card_name)]]
	return ""


## THE FIVE SENTENCES, one per rule, held as constants so that a refusal
## from [method legal] and a warning from [method offences] are the SAME
## WORDS about the same card. `%s`-slots, in order: see each use.
const BANNED_LINE := "%s is banned%s."
const OVER_COPIES := "%d copies of %s%s — the limit is %d (basic lands excepted)."
const OVER_RESTRICTED := "%d copies of %s%s — restricted cards are limited to one."
const BARS_RESTRICTED := "%s is on the restricted list, which this format bars entirely%s."
const SINGLETON_LINE := "%s appears %d times%s — Highlander allows one of each card except basic lands."


## EVERY CARD THAT MAKES THIS DECK ILLEGAL IN EVERY FORMAT BUT
## [constant UNRESTRICTED] — one line each, sorted, naming the card.
##
## [method legal] answers a different question and answers it differently:
## it takes ONE format and stops at the FIRST refusal, which is what a gate
## wants. A deck builder wants the whole list at once, because the player
## is about to go and fix them, and a warning that names one of five
## offences sends them back four more times.
##
## The three rules are the three the owner asked the builder to analyse —
## more than four copies, the restricted list, the banned list — and they
## are exactly the ones that hold in all four non-Unrestricted formats, so
## this needs no format argument. What it deliberately does NOT report is a
## SINGLE copy of a restricted card: that is legal in
## [constant RESTRICTED_T1] and only bars [constant TOURNAMENT_T15], so it
## is a fact about which format the deck fits ([method classify]) rather
## than a mistake. Reporting it would cry wolf on every deck with a Sol
## Ring in it.
##
## [param sideboard] counts with the maindeck, as it does everywhere else
## here, and each line says how many of the copies are in it.
static func offences(cards: Array, sideboard: Array = []) -> Array[String]:
	return offences_of(nonbasic_counts(both_piles(cards, sideboard)),
		nonbasic_counts(sideboard))


## [method offences] asked of `name -> copies` DICTIONARIES rather than of
## expanded card lists — the shape a deck builder already holds
## ([member DeckModel.counts]), and the reason this split exists: the Deck
## Builder's legality line asks this question on every card click, and
## expanding a 500-card deck into an array to count it back down again
## would put an O(cards) walk on a path the third audit pass got down to
## 1.0 ms. This one is O(distinct cards).
##
## [param counts] must already be basic-land-free ([method nonbasic_counts]
## does that) and must span BOTH piles; [param side_counts] is the
## sideboard alone, and is used only to say where the copies are.
static func offences_of(counts: Dictionary, side_counts: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for card_name in counts:
		var copies: int = counts[card_name]
		var where := _where(side_counts, card_name)
		if _banned_set().has(card_name):
			found.append(BANNED_LINE % [card_name, where])
		elif copies > COPY_LIMIT:
			found.append(OVER_COPIES % [copies, card_name, where, COPY_LIMIT])
		elif _restricted_set().has(card_name) and copies > 1:
			found.append(OVER_RESTRICTED % [copies, card_name, where])
	found.sort()
	return found


## THE TWO LISTS AS SETS. `Array.has` is a linear scan, and the lists are
## 55 and 12 entries long; a 200-unique deck asking on every card click is
## ~13,000 string comparisons a click. Built once per process, from the
## arrays, so the arrays stay the readable declaration.
static var _restricted_lookup: Dictionary = {}
static var _banned_lookup: Dictionary = {}


static func _restricted_set() -> Dictionary:
	if _restricted_lookup.is_empty():
		for card_name in RESTRICTED:
			_restricted_lookup[card_name] = true
	return _restricted_lookup


static func _banned_set() -> Dictionary:
	if _banned_lookup.is_empty():
		for card_name in BANNED:
			_banned_lookup[card_name] = true
	return _banned_lookup


## The two piles as one array. Public because the Deck Builder counts the
## same way when it advises about copies.
static func both_piles(cards: Array, sideboard: Array) -> Array:
	if sideboard.is_empty():
		return cards
	var out: Array = cards.duplicate()
	out.append_array(sideboard)
	return out


## " (2 in the sideboard)", or "" when the card is only in the maindeck —
## a refusal that names a card the player cannot see in the deck area is a
## refusal they cannot act on.
static func _where(side_counts: Dictionary, card_name: String) -> String:
	var in_side := int(side_counts.get(card_name, 0))
	return "" if in_side == 0 else " (%d in the sideboard)" % in_side


## What the ORIGINAL would call this deck — `check_deck_type()` run
## forwards, most permissive answer wins (`deckdll.cpp:3174-3191`). Not
## used to police anything; it is what the Deck Builder's Stats title bar
## showed (*"The Deck Builder displays your deck name and deck type… in
## the title bar when you click the Stats button"*, MicroProse ManaLink
## 1.3 Readme), and it is the honest way to tell a player which formats
## their deck already fits.
##
## [param sideboard] is counted with the maindeck for the same reason
## [method legal] counts it, and defaults to empty so the original's own
## one-pile algorithm is what an empty sideboard reproduces exactly. A
## classification that ignored the sideboard would name a format that
## [method legal] then refuses.
static func classify(cards: Array, sideboard: Array = []) -> String:
	var counts := nonbasic_counts(both_piles(cards, sideboard))
	if counts.is_empty():
		return HIGHLANDER
	var duplicates := false
	for card_name in counts:
		if counts[card_name] > 1:
			duplicates = true
			break
	if not duplicates:
		return HIGHLANDER          # the original's own early return
	var found := {}
	for card_name in counts:
		var copies: int = counts[card_name]
		if BANNED.has(card_name) or copies > COPY_LIMIT:
			found[UNRESTRICTED] = true
		elif not RESTRICTED.has(card_name):
			found[TOURNAMENT_T15] = true
		elif copies <= 1:
			found[RESTRICTED_T1] = true
		else:
			found[WILD] = true
	for format in ORDER:
		if found.has(format):
			return format
	return HIGHLANDER


## One line saying what a format allows, for the setup screen's tooltip
## and the Help page's summary. Ours, not 1997's — the original shipped no
## explanation of these anywhere.
const SUMMARY := {
	UNRESTRICTED: "Anything goes: no banned cards, no copy limit, no list.",
	WILD: "At most four of any card, and no banned cards — but the restricted list is ignored.",
	RESTRICTED_T1: "At most four of any card, no banned cards, and at most ONE copy of a restricted card.",
	TOURNAMENT_T15: "At most four of any card, no banned cards, and no restricted card at all.",
	HIGHLANDER: "One of each card, except basic lands. No list is involved.",
}

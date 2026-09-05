class_name HelpPages
extends RefCounted
## THE CONTENT OF THE HELP SCREEN — every word and every icon, as pure
## data, so it can be tested without a scene and so [HelpScreen] stays a
## renderer. Read that file's header for how the screen works; read this
## one for what may go on a page.
##
## ================================ THE RULES OF THIS FILE ================
##
## **1. Nothing here is written from memory.** Magic's rules are easy to
## half-remember and get subtly wrong. Every claim traces to one of:
##
##   * the **1997 MicroProse manual** — the primary authority. Its teaching
##     chapters are ch.8 "The Duel" (pp.59-106) and ch.9 "Dueling in
##     Shandalar" (pp.107-132); the Glossary is pp.159-186 and the
##     "Appendix: Sequence of Play" pp.187-194. Page numbers are PRINTED
##     pages, the convention `docs/glossary-1997.md` uses, and that file is
##     where many of these quotations were already collected and checked.
##   * **`shandalar-src/Duel.hlp`** — the game's OWN shipped help file, the
##     "Dueling Help" the manual points at. Its rules topics ("Mana",
##     "Phases", "Combat Bar", "Stop"…) are cited by topic name.
##   * the **string tables** — `@CUECARD_*` in
##     `shandalar-src/Program/UIStrings.txt` carries the one-line
##     explanation the original itself showed for each icon, and those are
##     reproduced verbatim rather than reworded. Deck-builder cue cards
##     come from `s30/assets/text/Cuecards.txt`, the genuine 1997 copy.
##   * **`docs/mechanics.md`** — for what OUR engine actually does. A page
##     may not promise a rule we have not built, and the page on damage
##     says outright which 1997 structure we lack.
##
## A [constant QUOTE] block is the original's own sentence and always
## names its source; unquoted prose is ours. A test enforces the second
## half of that.
##
## **2. The icon inventory comes from the CODE, not from guesswork.** Every
## entry's texture is fetched through the very accessor the duel screen or
## the deck builder uses to draw it — [method MiniCard.badge_from_slot],
## [method ManaIcons.symbol], [method FilterBar.sheet_cell] and the rest —
## so a cell index that drifts breaks the help screen's test at the same
## moment it breaks the screen it documents. Nothing is reproduced by eye,
## and no icon appears here that the player cannot actually meet: the
## ability sheet has eighteen cells and our mini card draws twelve of them,
## so twelve are explained. **Cell 17 is BLANK** — 484/484 px of solid
## black — so nothing is ever explained from it (s30 maps Menace there;
## see [constant MiniCard.BADGE_SLOT]).
##
## The ability sheet's own reading was CONFIRMED against the 1997 word
## list `@ABILITYWORDS` (`UIStrings.txt`), whose seventeen entries —
## Flying, Reach, Banding, Trample, First strike, Regenerates, the five
## landwalks, the five colour protections, protection from artifacts — are
## exactly the sheet's seventeen drawn cells. The names on the badge page
## are that table's, verbatim.
##
## **3. The word "interrupt" is banned here**, as `docs/glossary-1997.md`
## §5 bans it everywhere: the 1997 rules had a timing tier faster than an
## instant, it was abolished in 1999, our engine has no such tier, and no
## card in our pool prints the word (our type lines are Scryfall's modern
## ones). Using it in the HELP would promise timing we do not implement,
## which is the one thing a help screen must never do. Where a source
## sentence opens with it, the quotation is elided and marked.
##
## **4. Where 1997 and modern Magic genuinely differ**, the page says what
## the Options switch does rather than picking a side —
## [constant RulesOptions.FORKS] is the list.
##
## **5. Anything unconfirmed says so on the page.** Filling a gap with a
## plausible invention is the one failure this screen cannot afford.

# ------------------------------------------------------------ the shape --

## Block kinds a page may contain.
const HEADING := "heading"     ## A section title inside a page.
const TEXT := "text"           ## Our own prose.
const QUOTE := "quote"         ## A sourced quotation: `text` + `cite`.
const ICONS := "icons"         ## A list of `entries` (see below).
const KINDS: Array[String] = [HEADING, TEXT, QUOTE, ICONS]

## Icon sources. Each names the accessor that the SCREEN ITSELF draws the
## icon with — see [method icon_texture].
const SRC_MANA := "mana"       ## `sym` — the 1997 mana-symbol sheet.
const SRC_BADGE := "badge"     ## `slot` — the ability/protection sheet.
const SRC_STRIPE := "stripe"   ## `color` — the mana stripes on a title bar.
const SRC_SPRITE := "sprite"   ## `key` — an image+mask sprite.
const SRC_TEXTURE := "texture" ## `key` — a whole skin texture.
const SRC_PHASE := "phase"     ## `slot` — one Phase Bar icon.
const SRC_COMBAT := "combat"   ## `slot` — one Combat Bar icon.
const SRC_FILTER := "filter"   ## `row`/`col` — a deck-builder medallion.
const SRC_SET := "set"         ## `code` — a set symbol.
const SRC_CURSOR := "cursor"   ## the targeting cursor.
const SRC_DRAWN := "drawn"     ## no texture: the game draws this in code.


## The reference, in reading order: the newcomer's primer first, then the
## icon reference — the duel's icons, then the deck builder's.
static func pages() -> Array:
	return [
		_page_duel(),
		_page_table(),
		_page_mana(),
		_page_colors(),
		_page_card(),
		_page_card_kinds(),
		_page_turn(),
		_page_casting(),
		_page_combat(),
		_page_damage(),
		_page_start_finish(),
		_page_ruleset(),
		_page_formats(),
		_page_format_lists(),
		_page_icons_mana(),
		_page_icons_abilities(),
		_page_icons_protection(),
		_page_icons_small_card(),
		_page_icons_stripes(),
		_page_icons_phase_bar(),
		_page_icons_phase_marks(),
		_page_icons_combat_bar(),
		_page_icons_table(),
		_page_icons_builder_colors(),
		_page_icons_builder_sets(),
		_page_icons_builder_types(),
	]


# ---------------------------------------------------------- the primer --

static func _page_duel() -> Dictionary:
	return {"title": "The Duel", "blocks": [
		_quote("Players begin with a set amount of life — a life total. In "
			+ "the course of the duel, you will try to whittle your opponent "
			+ "down to 0 life while protecting yourself. The one who reaches "
			+ "0 first loses the duel.", "manual p.50"),
		_text("You damage your opponent by casting spells, by attacking "
			+ "with your creatures, and by using the magical effects of "
			+ "cards you have in play. They will be trying to do the same "
			+ "to you, and to stop you doing it to them."),
		_heading("The three ways a duel ends"),
		_quote("If, at the end of any phase of either player's turn or at "
			+ "the beginning or end of an attack, one player's life total "
			+ "is 0 or less, the other wins… If you can't draw a card when "
			+ "required to do so (your library is empty, for example), you "
			+ "lose the duel immediately.", "manual p.186, Glossary"),
		_text("Running out of cards is the second way, and it is not the "
			+ "same as an empty library: you lose at the moment you are "
			+ "asked to draw and cannot, so an empty deck kills you on your "
			+ "NEXT draw, not the instant it empties."),
		_quote("If a player gets ten poison counters, that player loses "
			+ "immediately, even if his or her opponent has negative life.",
			"Duel.hlp, topic \"Poison\""),
		_text("A standalone duel starts both wizards at the traditional 20 "
			+ "life. In the land of Shandalar the number varies: how much "
			+ "life you carry into a duel depends on how many cities you "
			+ "have mana links with (manual p.109)."),
		_heading("The one rule above all the others"),
		_quote("Remember the very first rule of Magic — if a card "
			+ "contradicts the rules, then the card takes precedence — the "
			+ "card is always right.", "manual p.52"),
	]}


static func _page_table() -> Dictionary:
	return {"title": "The Dueling Table", "blocks": [
		_text("The screen a duel is fought on is the DUELING TABLE, and "
			+ "every part of it has a name the game itself uses."),
		_quote("The largest areas of the dueling table are your territory "
			+ "and your opponent's territory. The lower territory is yours, "
			+ "the upper belongs to your adversary. These areas contain all "
			+ "of the cards in play.", "Duel.hlp, topic \"Territory\""),
		_heading("Down the left rail"),
		_text("The LIBRARY is your deck, face down. The GRAVEYARD beside it "
			+ "is your discard pile, and it is always face up — click it to "
			+ "look through, at any time, yours or your opponent's."),
		_text("The LIFE REGISTER shows each duelist's life, and their "
			+ "poison counters if they have any. To target your OPPONENT "
			+ "with a spell, you click their life register rather than a "
			+ "card. The MANA POOL beneath it holds mana you have tapped "
			+ "for but not yet spent."),
		_text("The SHOWCASE is the big card in the middle of the rail. "
			+ "Whatever you rest the pointer on is enlarged there."),
		_quote("The Showcase is a display only; it has no other function.",
			"Duel.hlp, topic \"Showcase\""),
		_text("The PHASE BAR is the vertical strip of icons between the "
			+ "rail and the territories. It has a page of its own further "
			+ "on; it is the control you will use most."),
		_heading("Your hand"),
		_quote("A small window floating over your territory contains "
			+ "representations of the cards in your hand. Only the title "
			+ "bar of your opponent's hand is visible; this is to keep you "
			+ "aware of how many cards are in that hand.",
			"Duel.hlp, topic \"Hands\""),
		_heading("The Situation Bar, and the keyboard"),
		_quote("Between the two territories (usually) is the Situation Bar. "
			+ "This is a reminder to you of what's going on and what you "
			+ "need to do.", "Duel.hlp, topic \"Situation Bar\""),
		_text("At its right-hand end is a Done button, a Cancel button, or "
			+ "both. The original documented exactly three keys, and they "
			+ "still work here: Esc is Cancel, Return is Done, and when "
			+ "there is only one button the Spacebar presses it."),
		_text("CUE CARDS are the game's own name for the little hints that "
			+ "pop up when you rest the pointer on something. Most of the "
			+ "icon explanations later in this reference are those very cue "
			+ "cards, quoted word for word."),
	]}


static func _page_mana() -> Dictionary:
	return {"title": "Mana — the fuel of every spell", "blocks": [
		_quote("Lands are the most common kind of card in Magic, since they "
			+ "usually provide the mana, the magical energy, for all your "
			+ "spells. You can put one land into play per turn, and you may "
			+ "use the land for mana as soon as it is in play.",
			"Duel.hlp, topic \"Lands\""),
		_text("That single land drop per turn is the throttle the whole "
			+ "game is built around. Playing a land costs nothing, but it "
			+ "may only be done in your own main phase, and only once."),
		_heading("Tapping"),
		_quote("Tapping a card means turning it sideways. This indicates to "
			+ "you and your opponent that the card's effects have been "
			+ "temporarily used up. Don't worry, your cards will untap at "
			+ "the beginning of your next turn, during your untap phase.",
			"Duel.hlp, topic \"Tap\""),
		_text("A cost written {T} means 'turn this card sideways to pay'. "
			+ "Lands are tapped for mana; many other cards are tapped to "
			+ "use an ability."),
		_heading("Mana is not land"),
		_quote("Note that mana and land are not the same thing. Mana can "
			+ "come from other sources besides land; Llanowar Elves, for "
			+ "example, is a creature that you can tap for one green mana. "
			+ "This is why the rules refer to \"green mana,\" \"blue "
			+ "mana,\" and so on, instead of \"forest mana,\" \"island "
			+ "mana,\" and such.", "Duel.hlp, topic \"Mana\""),
		_heading("Your mana pool"),
		_text("Mana you have produced but not yet spent sits in your MANA "
			+ "POOL, the column of colored rows beside your life register. "
			+ "It does not keep: the pool empties on its own at the end of "
			+ "every step. (The 1997 game emptied it at the end of each "
			+ "PHASE instead, and charged you a life for every point you "
			+ "wasted — 'mana burn'. Both are switches under Options; see "
			+ "the page on which rules this game plays by.)"),
		_heading("Reading a casting cost"),
		_quote("The casting cost is always written in mana symbols. For "
			+ "each of the five colors of mana, there is a separate, "
			+ "distinct symbol; each time that symbol appears, it "
			+ "represents one mana of the appropriate color. Numbers in "
			+ "gray circles represent generic mana, which can be any color, "
			+ "any combination of colors, or colorless.", "manual p.65"),
		_text("So {2}{W}{W} means two white mana plus two more of anything "
			+ "at all. {X} means you choose the number as you cast the "
			+ "spell and pay that much extra; the game asks you for it, and "
			+ "once you have chosen you cannot change your mind."),
	]}


static func _page_colors() -> Dictionary:
	# `Duel.hlp`, topic "Mana", carries the colour pie in the game's own
	# words; the printed manual gives the same five paragraphs twice
	# (pp.19-20 and pp.52-53). Quoted verbatim, one per colour, in WUBRG
	# order — the order our mana pool and Color Filters already use.
	var entries: Array = [
		_icon("White — the plains",
			"White magic draws its vitality from the untouched, open "
			+ "plains. Though white magicians focus on spells of healing "
			+ "and protection, they also devote plenty of time to the "
			+ "chivalrous acts of war. White's traditional foils are black "
			+ "and red.", {"src": SRC_MANA, "sym": "W"}, "{W}"),
		_icon("Blue — the islands",
			"Blue magic flows from the islands and thrives on mental "
			+ "energy. Other wizards fear the blue magicians' ability with "
			+ "artifice and illusion, as well as their mastery of the "
			+ "elemental forces of air and water. Blue's traditional foils "
			+ "are red and green.", {"src": SRC_MANA, "sym": "U"}, "{U}"),
		_icon("Black — the swamps",
			"Black magic's power comes from the swamps and bogs; it thrives "
			+ "on death and decay. Many wizards shun black magic's "
			+ "self-destructive nature even as they long for its "
			+ "ruthlessness. Black's traditional foils are green and white.",
			{"src": SRC_MANA, "sym": "B"}, "{B}"),
		_icon("Red — the mountains",
			"Red magic feeds on the vast energy boiling deep in the heart "
			+ "of the mountains. Masters of earth and fire, red magicians "
			+ "specialize in the violence of chaos and combat. Red's "
			+ "traditional foils are blue and white.",
			{"src": SRC_MANA, "sym": "R"}, "{R}"),
		_icon("Green — the forests",
			"Green magic gets its life from the lush fecundity of the "
			+ "forest. Like nature itself, green magic can bring both "
			+ "soothing serenity and thunderous destruction. Green's "
			+ "traditional foils are blue and black.",
			{"src": SRC_MANA, "sym": "G"}, "{G}"),
	]
	return {"title": "The five colors of magic", "blocks": [
		_quote("There are five different types of basic land, each of which "
			+ "produces mana of a different color. Plains produce white "
			+ "mana; islands, blue; swamps, black; mountains, red; and "
			+ "forests, green.", "manual p.52"),
		_text("Each color has its own character. The five paragraphs below "
			+ "are the game's own, from Duel.hlp's topic \"Mana\"."),
		{"kind": ICONS, "entries": entries},
		_heading("And the two that are not colors"),
		_quote("There are also \"colorless\" mana and \"generic\" mana, "
			+ "which are types of mana and do not count as colors.",
			"Duel.hlp, topic \"Mana\""),
		_text("GENERIC is what a number in a casting cost asks for: mana of "
			+ "any color, or colorless. COLORLESS mana comes from a few "
			+ "sources of its own, has no color at all, and can only pay "
			+ "generic costs — never a {W} or a {G}."),
		_heading("What color a card is"),
		_quote("A spell's color is technically defined as the color of the "
			+ "mana required to cast it, not counting the generic mana.",
			"Duel.hlp, topic \"Background\""),
		_text("A card needing two colors is both at once. Lands and "
			+ "artifacts need no colored mana, so they are colorless — and "
			+ "\"artifact\" is not a color."),
	]}


static func _page_card() -> Dictionary:
	return {"title": "The parts of a card", "blocks": [
		_text("Rest the pointer on any card and the Showcase enlarges it. "
			+ "Duel.hlp's own topic \"Parts of the Card\" numbers twelve "
			+ "parts; here they are, in its order."),
		_heading("The top"),
		_text("The NAME. Then the CASTING COST in mana symbols at the top "
			+ "right. On the small cards in play and in your hand the name "
			+ "is drawn YELLOW when you could cast or use that card right "
			+ "now and WHITE when you could not — the fastest read on the "
			+ "whole table."),
		_heading("The middle"),
		_text("The ART, and around it the BACKGROUND, which is the card's "
			+ "color. Under the picture is the CARD TYPE, and for a "
			+ "creature the CREATURE TYPE follows it. At that line's "
			+ "right-hand end sits the CARD SET ICON, the little symbol "
			+ "saying which set the card came from."),
		_quote("While the artwork on the Magic: The Gathering cards is "
			+ "beautiful, it is important to remember that the card's name, "
			+ "art, flavor text, and artist's name don't influence what a "
			+ "card actually does. For example, if you look at the picture "
			+ "on a Frozen Shade card, it looks as if the creature is "
			+ "floating. This may fool you into thinking that a Frozen "
			+ "Shade can fly, but since the text box doesn't include the "
			+ "word Flying, the Shade isn't considered a flying creature.",
			"Duel.hlp, topic \"Art\""),
		_heading("The text box"),
		_text("ABILITIES come first — flying, trample and the rest — "
			+ "followed by the card's EFFECTS. An effect you can pay to use "
			+ "is written cost : effect, and everything before the colon is "
			+ "its ACTIVATION COST. Anything in italics is FLAVOR TEXT and "
			+ "changes nothing."),
		_heading("The bottom"),
		_quote("All creatures have two numbers separated by a slash in the "
			+ "lower right corner of the card. The first of these numbers "
			+ "indicates the creature's power, the amount of combat damage "
			+ "this creature deals in combat. The second number represents "
			+ "the creature's toughness, the amount of damage the creature "
			+ "can absorb before it dies.", "Duel.hlp, topic \"Summons\""),
		_text("So a 2/3 deals 2 damage and is destroyed once 3 damage is "
			+ "marked on it. Any card with numbers in that corner is a "
			+ "creature. The ARTIST's name is beside them, and means "
			+ "nothing to the duel."),
	]}


static func _page_card_kinds() -> Dictionary:
	return {"title": "The kinds of card", "blocks": [
		_quote("There are two basic types of cards: spells and lands.",
			"Duel.hlp, topic \"Card Types\""),
		_text("Lands say \"Land\" between the picture and the text box. "
			+ "Everything else is a spell, and the type line says which "
			+ "kind. These are the six the Deck Builder's Type Filters "
			+ "use."),
		_heading("Spells that stay: the permanents"),
		_text("CREATURE — your attackers and blockers, brought in by a "
			+ "summon spell. A creature cannot attack, or pay a {T} cost, "
			+ "on the turn it arrives."),
		_text("ARTIFACT — a magical device. Artifacts generally need only "
			+ "generic mana, so any color can cast one. Some are creatures "
			+ "as well, and those two behave differently when tapped: a "
			+ "tapped non-creature artifact stops working, while a tapped "
			+ "artifact creature does not."),
		_text("ENCHANTMENT — lasting magic. One played on a target is "
			+ "LOCAL (an Aura, in today's word); one that simply sits on "
			+ "the table affecting the duel as a whole is GLOBAL. An "
			+ "Enchant World is a global enchantment with one extra rule: "
			+ "only one can be in play, and a new one buries the old."),
		_quote("Once a permanent is in play, you don't have to pay the "
			+ "casting cost again. The permanent will remain in play until "
			+ "it is destroyed.", "Duel.hlp, topic \"Spells\""),
		_heading("Spells that do their work and leave"),
		_text("SORCERY — castable only in your own main phase, when nothing "
			+ "else is waiting. It resolves and goes to the graveyard."),
		_text("INSTANT — the same, except you may cast it almost any time, "
			+ "including on your opponent's turn and in the middle of "
			+ "combat. An instant is one kind of FAST EFFECT, the 1997 "
			+ "game's umbrella word for everything you can do while "
			+ "something else is already happening."),
		_heading("Where cards go"),
		_text("Cards that have finished, and creatures that have died, go "
			+ "to their owner's GRAVEYARD, face up, where you may look "
			+ "through them whenever you like. A few cards instead REMOVE "
			+ "something FROM THE GAME: that card is set aside until the "
			+ "duel is over, never reaches a graveyard, and so triggers no "
			+ "graveyard effects at all."),
	]}


static func _page_turn() -> Dictionary:
	return {"title": "The turn and its phases", "blocks": [
		_quote("Dueling players take turns, and each player's turn is "
			+ "divided into six smaller parts called phases. You might not "
			+ "always have something to do during a given phase, but that "
			+ "phase still happens. The phases always take place in the "
			+ "same order: Untap, Upkeep, Draw, Main, Discard, Cleanup.",
			"Duel.hlp, topic \"Phases\""),
		_heading("What happens in each"),
		_text("UNTAP — every tapped card of yours turns upright again, all "
			+ "at once, and creatures that arrived last turn lose their "
			+ "summoning sickness. Neither player can act."),
		_text("UPKEEP — the first chance to act in the turn, and where "
			+ "anything saying 'during upkeep' happens. Some cards demand a "
			+ "payment here, and you cannot leave the phase until they have "
			+ "been dealt with."),
		_text("DRAW — you draw one card. Both players may act before and "
			+ "after the draw. Drawing is itself a fast effect."),
		_text("MAIN — the body of your turn, and the only time you may play "
			+ "a land, cast a sorcery or a permanent, or attack."),
		_text("DISCARD — if you are holding more than seven cards you must "
			+ "discard down to seven. You may not discard if you have seven "
			+ "or fewer, even if you would like to."),
		_text("CLEANUP — damage is wiped from every surviving creature and "
			+ "every 'until end of turn' effect expires, both at the same "
			+ "instant. Nobody can act. Then the turn is over."),
		_quote("There is no time \"between phases\" for things to happen; "
			+ "all actions and effects take place during one or another of "
			+ "the phases.", "Duel.hlp, topic \"Phases\""),
		_heading("Main is really three parts"),
		_quote("Main Pre-Combat is everything that happens before the "
			+ "attack… Combat is the part of the phase that can get the "
			+ "most complicated… Main Post-Combat is everything that "
			+ "happens after the attack.", "Duel.hlp, topic \"Main Phase\""),
		_text("That is why the Phase Bar shows EIGHT icons per player "
			+ "rather than six: Main is drawn as its three parts. You may "
			+ "cast spells, play your one land, and make your one attack in "
			+ "whatever order you like — but not during the attack itself."),
	]}


static func _page_casting() -> Dictionary:
	return {"title": "Casting spells and the Spell Chain", "blocks": [
		_text("Any card you can cast is highlighted. Click it, pay the "
			+ "cost, and — if the spell needs one — pick a target: the "
			+ "pointer becomes the targeting cursor and you click a card, "
			+ "or a life register to aim at a player."),
		_quote("A target is the specific permanent, spell, or player at "
			+ "which a spell or effect is aimed… the caster must announce "
			+ "the target at the time she pays the cost of and plays the "
			+ "spell or effect; it cannot be changed later.",
			"Duel.hlp, topic \"Target\""),
		_heading("Nothing happens at once"),
		_text("A spell you have just cast does not simply take effect. "
			+ "Both players get the chance to answer it with something "
			+ "faster, and those answers pile up on top of it. The pile is "
			+ "the SPELL CHAIN, and the game shows it to you in a window of "
			+ "that name."),
		_quote("When both players signal that they are done using fast "
			+ "effects, all of the spells are resolved in reverse order of "
			+ "casting. That is, the last cast takes effect first, and they "
			+ "proceed in LIFO order — last in, first out — until you "
			+ "finally reach the original spell or effect.",
			"manual p.174, Glossary \"LIFO Rule\""),
		_heading("Fast effects"),
		_quote("…instants, mana sources, and non-continuous effects of "
			+ "permanents are called fast effects. Unless otherwise "
			+ "specified on the card, you can use fast effects only during "
			+ "the upkeep, draw, main and discard phases of any player's "
			+ "turn.", "Duel.hlp, topic \"Fast Effect\" (elided — see note)"),
		_text("A fast effect is anything you can do while something else is "
			+ "already under way: an instant from your hand, an ability of "
			+ "a card already in play, or simply tapping a land for mana. "
			+ "When the game asks 'Fast Effects?' it is offering you that "
			+ "window. Tapping for mana is special: it is a MANA SOURCE, "
			+ "and nothing can respond to it."),
		_text("The elision above hides a third category the 1997 rules "
			+ "had — a tier of effect faster than an instant, abolished "
			+ "from Magic in 1999. This engine follows modern timing and "
			+ "has no such tier, so naming it here would promise you "
			+ "something the game cannot do."),
		_heading("When it goes wrong"),
		_quote("If, at the time it resolves, a spell or effect finds that "
			+ "one or more of its targets are no longer valid, it is said "
			+ "to fizzle with respect to any now-invalid target… If none of "
			+ "the targets remains valid, the effect as a whole fizzles, "
			+ "and even its non-targeted effects do not occur.",
			"Duel.hlp, topic \"Fizzle\""),
		_text("A fizzle is not a take-back. CANCEL is: change your mind "
			+ "before you have finished paying, and the spell goes back to "
			+ "your hand as though nothing had happened. Any mana you had "
			+ "already produced stays in your pool, though — the original's "
			+ "help puts it in capitals, and so will we: DO NOT CONFUSE A "
			+ "FIZZLE WITH A CANCEL."),
	]}


static func _page_combat() -> Dictionary:
	return {"title": "Combat", "blocks": [
		_quote("You only get one attack during your turn, and none during "
			+ "your opponent's turn. You attack your opponent with your "
			+ "creatures.", "Duel.hlp, topic \"Attack\""),
		_text("You cannot attack a creature — only a player. Clicking the "
			+ "combat icon on the Phase Bar announces that you INTEND to "
			+ "attack; the attack itself begins a moment later, after both "
			+ "sides have had their last chance to act before it."),
		_heading("Declaring the attack"),
		_text("Your creatures that can attack are highlighted; click each "
			+ "one to add it to the lineup. Attacking taps them. A tapped "
			+ "creature and a summoning-sick creature cannot attack, and "
			+ "nor can a Wall."),
		_quote("As soon as you add the first creature to the attack, the "
			+ "Combat window opens. Your attackers line up on your side, "
			+ "and the space on the other side is reserved for (potential) "
			+ "blockers.", "Duel.hlp, topic \"Combat\""),
		_heading("Blocking"),
		_quote("Multiple creatures can block a single attacker, but no "
			+ "creature can block more than one attacker (unless, of "
			+ "course, a card specifically gives it that ability).",
			"Duel.hlp, topic \"Declare Blockers\""),
		_text("Blocking does not tap a creature, but a tapped creature "
			+ "cannot block. Red arrows on the board show which blocker is "
			+ "facing which attacker."),
		_quote("Once a block has been declared, the blocked attacking "
			+ "creatures have been blocked and will remain blocked no "
			+ "matter what happens to the blocker later.",
			"Duel.hlp, topic \"Declare Blockers\""),
		_text("That rule catches everyone once. Killing the blocker does "
			+ "not let the attacker through, and neither does giving the "
			+ "attacker flying after the fact — do those things BEFORE "
			+ "blockers are declared."),
		_heading("Damage"),
		_text("Each creature deals damage equal to its power. Blocked "
			+ "attackers hit their blockers and are hit back at the same "
			+ "instant, so both can die; unblocked attackers hit the "
			+ "defending player. If several creatures block one attacker, "
			+ "its controller divides its damage among them."),
		_text("FIRST STRIKE splits that into two waves: first-strikers deal "
			+ "theirs, anything killed by it dies without striking back, "
			+ "and only then does everything else deal its damage."),
		_text("TRAMPLE lets a blocked attacker push the surplus through — "
			+ "give each blocker lethal damage and the excess spills onto "
			+ "the defending player. It does nothing while blocking."),
	]}


static func _page_damage() -> Dictionary:
	return {"title": "Damage, death and regeneration", "blocks": [
		_quote("Each 1 damage done to a player results in a loss of 1 life, "
			+ "unless the damage is prevented or redirected. Any time that "
			+ "a creature has been dealt damage equal to or exceeding its "
			+ "toughness, it is considered to have taken lethal damage and "
			+ "is destroyed.", "Duel.hlp, topic \"Damage\""),
		_text("Damage on a creature is MARKED on it — you will see the "
			+ "damage marker and a number on the small card — and it stays "
			+ "there until the cleanup step, so two small hits in one turn "
			+ "add up. Damage on a player comes straight off their life."),
		_heading("Prevention, healing, destruction"),
		_text("PREVENTION stops damage before it lands; a Circle of "
			+ "Protection is the classic. HEALING repairs damage already "
			+ "done. DESTROY is a third thing entirely and is not damage at "
			+ "all — it ignores toughness, and damage prevention cannot "
			+ "touch it."),
		_text("Reducing a creature's TOUGHNESS is a fourth. If an effect "
			+ "drops a creature's toughness to the point where the damage "
			+ "on it is lethal — or to 0 with no damage at all — it dies, "
			+ "and no prevention applies."),
		_heading("Regeneration"),
		_quote("Regeneration is useful when a creature is destroyed, "
			+ "whether that destruction is the result of lethal damage or "
			+ "an effect. Regeneration prevents the creature from going to "
			+ "the graveyard. In the process, regenerating a creature also "
			+ "removes all damage that has been dealt to that creature.",
			"Duel.hlp, topic \"Regeneration\""),
		_text("A regenerated creature becomes tapped, keeps its "
			+ "enchantments, and — if this happened in combat — is removed "
			+ "from the combat and neither deals nor takes any more damage "
			+ "this turn."),
		_quote("If a permanent is buried, it is put into its owner's "
			+ "graveyard. Nothing can prevent this.",
			"Duel.hlp, topic \"Bury\""),
		_text("So a card that BURIES a creature beats regeneration, and so "
			+ "does one that removes it from the game."),
		_heading("What this remake does not have"),
		_text("The 1997 game paused for a DAMAGE PREVENTION STEP every "
			+ "single time damage was dealt, giving both players a window "
			+ "in which prevention, redirection and regeneration — and "
			+ "nothing else — could be used. This engine has no such step: "
			+ "prevention here comes from effects that are already in place "
			+ "when the damage happens, and regeneration from a shield put "
			+ "up beforehand. It is the largest structure on this page that "
			+ "the original had and we do not."),
	]}


static func _page_start_finish() -> Dictionary:
	return {"title": "Starting and finishing a duel", "blocks": [
		_heading("Who goes first"),
		_quote("In every duel, one player plays first and the other draws "
			+ "first. Who does which is decided by the player who wins a "
			+ "coin toss (unless one player has a preexisting advantage). "
			+ "The player who gets First Play does not draw a card during "
			+ "her first turn.", "Duel.hlp, topic \"Play or Draw Rule\""),
		_heading("The mulligan"),
		_text("This game's mulligan is not the modern one, and it is worth "
			+ "knowing exactly: you may redraw only if your seven cards "
			+ "contain no land or nothing but land, you get seven fresh "
			+ "cards rather than one fewer, and you get one chance."),
		_quote("If either player draws no land in this seven cards or draws "
			+ "all land, then that player has the option to declare a "
			+ "mulligan… If either player declares a mulligan, that player "
			+ "must shuffle her hand back into her library and draw seven "
			+ "new cards to make an initial hand. The other player has the "
			+ "option to do so as well… Each player has only one chance to "
			+ "redraw.", "Duel.hlp, topic \"Mulligan\""),
		_heading("Ante"),
		_quote("In Shandalar, all duels are played \"for keeps.\" That is, "
			+ "both players chance losing one or more cards to their "
			+ "opponent. The cards that are at risk in a duel are called "
			+ "the ante. The winning player keeps those cards after the "
			+ "duel is over.", "Duel.hlp, topic \"Ante\""),
		_heading("A draw"),
		_text("If both players would lose at the same moment, nobody wins: "
			+ "the duel is a draw, and each takes back their own ante."),
		_heading("Conceding"),
		_text("The original let a player concede at any time, ending the "
			+ "duel immediately, with a confirmation first. This remake has "
			+ "no concede button yet."),
	]}


static func _page_ruleset() -> Dictionary:
	var blocks: Array = [
		_text("The 1997 game played by the Fifth Edition rules of its day. "
			+ "This remake's engine follows the modern Comprehensive Rules, "
			+ "which is what a card's printed text assumes today. In a "
			+ "handful of places the two genuinely disagree, and rather "
			+ "than choose silently, each one is a switch under Options."),
		_quote("This version of Magic: The Gathering enforces the official "
			+ "Fifth Edition rules.", "manual p.108"),
		_heading("The switches, and what each one changes"),
	]
	for fork in RulesOptions.FORKS:
		var built: bool = RulesOptions.IMPLEMENTED.has(fork["key"])
		var body: String = String(fork["label"]) + " — 1997: " \
			+ String(fork["fifth"]) + "  Modern: " + String(fork["modern"])
		if not built:
			body += "  (Not built yet — the switch is greyed out.)"
		blocks.append(_text(body))
	# The count comes from the table, not from a number typed here: it read
	# "all six" for one pass after a seventh fork arrived (§6.8).
	blocks.append(_text("Options offers all %d at once as 'Modern rules' or "
		% RulesOptions.FORKS.size()
		+ "'1997 — Fifth Edition', and shows 'Custom' when you have mixed "
		+ "them. Clicking a rule's own name there explains it again, with "
		+ "the source it was taken from."))
	blocks.append(_heading("Other places we differ, deliberately"))
	blocks.append(_text("Defensive banding does nothing here; only attacking "
		+ "bands exist. One creature cannot block two attackers. And the "
		+ "original's Discard phase is our cleanup step, which stops and "
		+ "asks you what to throw away exactly as the 1997 phase did."))
	return {"title": "Which rules this game plays by", "blocks": blocks}


# --------------------------------------------------------- deck formats --
#
# THE ONE PLACE IN THIS FILE WITH NO 1997 EXPLANATION TO QUOTE. The five
# format names are the original's own (`@SHELLPAGE_MULTIDUEL`,
# `Program/Text.res:2854-2859`), but the game never told a player what any
# of them meant: the 220-page manual does not contain the words
# "Unrestricted", "Highlander" or "Type 1.5" anywhere, and `Duel.hlp` has
# no format topic. So these two pages describe what OUR code does
# ([DeckFormat]), which was written from the game's own classifier, and
# they say so on the page — rule 5 of this file.

static func _page_formats() -> Dictionary:
	return {"title": "Deck formats — the five", "blocks": [
		_text("Before a duel you may require a deck format. The five are "
			+ "the 1997 game's own, in its own words and its own order, "
			+ "from the top of its pre-duel parameter screen. The game "
			+ "never explained them to players — its manual does not "
			+ "contain the words \"Unrestricted\", \"Highlander\" or "
			+ "\"Type 1.5\" at all — so the descriptions below are ours, "
			+ "written from the classifier in the game's own deck code."),
		_quote("The Deck Builder displays your deck name and deck type "
			+ "(Unrestricted, Wild, Restricted, Tournament or Highlander) "
			+ "in the title bar when you click the Stats button.",
			"MicroProse, ManaLink 1.3 Readme, 1 May 1998"),
		_heading("Unrestricted"),
		_text("Anything goes. No banned cards, no copy limit, no list. "
			+ "This is the setting a duel starts on, and the only one that "
			+ "can never refuse a deck."),
		_heading("Wild"),
		_text("At most four copies of any one card, and no banned cards — "
			+ "but the restricted list is ignored, so two Black Lotuses "
			+ "are fine."),
		_heading("Restricted (Type 1)"),
		_text("At most four copies of any one card, no banned cards, and "
			+ "at most ONE copy of a card on the restricted list."),
		_heading("Tournament (Type 1.5)"),
		_text("At most four copies of any one card, no banned cards, and "
			+ "no card from the restricted list at all."),
		_heading("Highlander"),
		_text("One of each card. No list is involved, and no card is "
			+ "banned — the rule is simply that no card may appear twice."),
		_heading("Basic lands are always exempt"),
		_text("Every copy limit above ignores basic lands, including "
			+ "Highlander's. That is the game's own rule for its own "
			+ "decks, and the manual states it while giving Shandalar a "
			+ "duplicate limit that changes with deck size rather than a "
			+ "flat four."),
		_quote("In addition to that, how many cards you have in your deck "
			+ "can limit the number of copies of each card you're allowed "
			+ "to have… This limitation does not apply to basic lands, of "
			+ "course, but to all other cards.", "the 1997 manual, p.139"),
	]}


static func _page_format_lists() -> Dictionary:
	return {"title": "Deck formats — the lists", "blocks": [
		_heading("What is enforced today"),
		_text("All five formats are enforced. Choosing one on the battle "
			+ "setup screen refuses a deck that does not meet it, naming "
			+ "the card that broke the rule, before the duel starts. "
			+ "Highlander and Unrestricted need no list at all; the other "
			+ "three read the two lists below."),
		_heading("Your sideboard is part of your deck"),
		_text("Every limit on this page counts your sideboard with your "
			+ "maindeck: four Lightning Bolt in the deck and one in the "
			+ "sideboard is five copies, and a banned card cannot hide in "
			+ "the sideboard either. That is not a 1997 rule — the 1997 "
			+ "Deck Builder had no sideboard at all — it is modern "
			+ "Magic's, adopted here because a match really does move "
			+ "cards between the two piles between duels."),
		_heading("Where the lists come from — and how old they are"),
		_text("This is worth being exact about, because the answer is not "
			+ "the tidy one. No 1997 restricted list survives in any file "
			+ "this project can read. The list started as the one in the "
			+ "game's own modern deck code, and as written that contains "
			+ "cards printed a decade after 1997."),
		_text("This page used to say the card pool sorted that out by "
			+ "itself — that a card can only matter if a deck can hold it, "
			+ "so what survived the 1997 pool was the era's own list. That "
			+ "was WRONG, and it was corrected in September 2026. It holds "
			+ "for cards ADDED to the list since 1997: they are not in "
			+ "this pool, so no deck can hold one. It fails completely for "
			+ "cards REMOVED from it since — those are in the pool, and "
			+ "eleven of them were going unflagged."),
		_text("So the list is now the union of two: the modern one, kept "
			+ "whole so a card added to the pool later becomes restricted "
			+ "at that moment instead of being quietly legal, plus the "
			+ "DCI's own Classic (Type 1) restricted list as printed in "
			+ "The Duelist #22 of 1 January 1998 — which is the closest "
			+ "contemporary source that survives. Three cards are on the "
			+ "modern list, in this pool, and NOT on the 1998 one (Mana "
			+ "Crypt, Mana Vault and Time Vault); they are left restricted "
			+ "rather than quietly loosened."),
		_heading("Restricted — one copy allowed"),
		_text("Of that list, these are the cards this remake can actually "
			+ "deal you: Ancestral Recall, Balance, Berserk, Black Lotus, "
			+ "Black Vise, Braingeyser, Demonic Tutor, Fastbond, Fork, "
			+ "Ivory Tower, Library of Alexandria, Mana Crypt, Mana Vault, "
			+ "Maze of Ith, Mind Twist, Mirror Universe, Mox Pearl, Mox "
			+ "Sapphire, Mox Jet, Mox Ruby, Mox Emerald, Recall, Regrowth, "
			+ "Sol Ring, Strip Mine, Time Vault, Time Walk, Timetwister, "
			+ "Underworld Dreams and Wheel of Fortune."),
		_heading("Banned — no copies allowed"),
		_text("The ante cards: Bronze Tablet, Contract from Below, "
			+ "Darkpact, Demonic Attorney, Jeweled Bird, Rebirth and "
			+ "Tempest Efreet. The game's list also bans Amulet of Quoz, "
			+ "Chaos Orb, Falling Star and Shahrazad, none of which this "
			+ "remake has built yet."),
		_heading("A word that means two things"),
		_text("\"Restricted\" is also the name of a card FILTER in the "
			+ "Deck Builder, and there it means something else entirely — "
			+ "the rare cards Shandalar hands out as treasure. The "
			+ "Glossary lists both meanings, in that order."),
		_quote("Restricted (1) In Shandalar, one can sometimes gain cards "
			+ "as treasure that are especially valuable and not part of "
			+ "the 4th Edition or Astral card sets. For the purposes of "
			+ "the Deck Builder, these cards are collected under the "
			+ "general heading of Restricted. (2) Generally speaking, a "
			+ "card the use of which is limited in certain types of "
			+ "dueling tournaments.", "the 1997 manual, Glossary, p.180"),
	]}



# ------------------------------------------------- the icon reference --

static func _page_icons_mana() -> Dictionary:
	var entries: Array = [
		_icon("{W} — white mana", "One white mana, from a Plains or another "
			+ "white source. Only it can pay a {W} in a casting cost.",
			{"src": SRC_MANA, "sym": "W"}, "{W}"),
		_icon("{U} — blue mana", "One blue mana, from an Island. Blue's "
			+ "letter is U because B was already taken by black.",
			{"src": SRC_MANA, "sym": "U"}, "{U}"),
		_icon("{B} — black mana", "One black mana, from a Swamp.",
			{"src": SRC_MANA, "sym": "B"}, "{B}"),
		_icon("{R} — red mana", "One red mana, from a Mountain.",
			{"src": SRC_MANA, "sym": "R"}, "{R}"),
		_icon("{G} — green mana", "One green mana, from a Forest.",
			{"src": SRC_MANA, "sym": "G"}, "{G}"),
		_icon("{0} — free", "Costs no mana at all. You must still be "
			+ "allowed to cast or activate it.",
			{"src": SRC_MANA, "sym": "0"}, "{0}"),
		_icon("{1} to {10} — generic mana", "A plain number is GENERIC: pay "
			+ "it with any mana, of any color, or with colorless. So {3}{R} "
			+ "is one red mana plus three of anything.",
			{"src": SRC_MANA, "sym": "3"}, "{3}"),
		_icon("{X} — you choose", "You decide the number as you cast the "
			+ "spell and pay that much extra; the card's text then uses X. "
			+ "The game asks you for it, and the choice is final.",
			{"src": SRC_MANA, "sym": "X"}, "{X}"),
		_icon("{T} — tap this card", "A cost, not an effect: turn this card "
			+ "sideways to pay it. Whatever the card does is written after "
			+ "the symbol. A creature cannot pay {T} on the turn it "
			+ "arrived.", {"src": SRC_MANA, "sym": "T"}, "{T}"),
	]
	return {"title": "Icons — the mana symbols", "blocks": [
		_text("The original's mana sheet holds nineteen symbols: {X}, the "
			+ "numbers {0} through {10}, the five colors, and the tap "
			+ "symbol. You meet them on the enlarged card in the Showcase, "
			+ "and at a small card's bottom-left corner, where they show an "
			+ "ability you can pay to use."),
		{"kind": ICONS, "entries": entries},
		_text("Colorless mana has no symbol of its own in a cost — cards "
			+ "that make it say so in words. It pays generic costs like any "
			+ "other mana, and nothing else. Your mana pool shows it in its "
			+ "own row, which the original's cue card names 'Your mana "
			+ "pool: amount of Colorless'."),
	]}


static func _page_icons_abilities() -> Dictionary:
	# Names are `@ABILITYWORDS` (UIStrings.txt) verbatim; the explanations
	# are condensed from `Duel.hlp`'s topic for each ability.
	var entries: Array = [
		_badge_icon(Mtg.Keyword.FLYING, "Flying — a wing",
			"Only creatures with flying or with Reach can block it. It can "
			+ "block anything, flying or not. You cannot switch flying off "
			+ "to invite a block."),
		_badge_icon(Mtg.Keyword.REACH, "Reach — a spider's web",
			"The 1997 game called this Web: a creature that does not fly "
			+ "itself but can block creatures that do."),
		_badge_icon(Mtg.Keyword.TRAMPLE, "Trample — a footprint",
			"When this attacker is blocked, give each blocker lethal damage "
			+ "and the excess spills over onto the defending player. It "
			+ "does nothing while the creature is blocking."),
		_badge_icon(Mtg.Keyword.FIRST_STRIKE, "First strike — a striking sword",
			"It deals its combat damage in a wave of its own, before "
			+ "creatures without first strike. Anything it kills never "
			+ "strikes back — but a survivor still hits it."),
		_icon("Regenerates — a green trident",
			"The creature can be saved from destruction, but not for "
			+ "free: pay the cost written on the card and it gets a "
			+ "shield. The next time it would be destroyed the shield is "
			+ "spent instead — the creature taps, its damage is wiped and "
			+ "it is removed from combat. Unlike the abilities above this "
			+ "one has an ACTIVATION COST, so the card wears its mana "
			+ "symbol too.",
			{"src": SRC_BADGE, "slot": MiniCard.REGENERATION_SLOT}, "R", 32.0),
		_badge_icon(Mtg.Keyword.BANDING, "Banding — a cross",
			"An old and unusual ability. Creatures with banding may attack "
			+ "together as one group, which must be blocked as one, and "
			+ "their controller divides the blockers' damage among them. "
			+ "NOTE: only attacking bands are implemented in this remake — "
			+ "banding on a blocker does nothing here."),
	]
	return {"title": "Icons — abilities on a card in play", "blocks": [
		_quote("Many creatures have one of the following abilities. "
			+ "Abilities are the first thing listed in the text box of a "
			+ "summon (creature) card. Abilities have no activation cost; "
			+ "they're a built-in characteristic of the creature, and thus "
			+ "are always in effect.", "Duel.hlp, topic \"Abilities\""),
		_text("They are drawn as badges along a small card's bottom edge, "
			+ "left to right, and only for cards IN PLAY — the original "
			+ "badges the table, not your hand. The names below are the "
			+ "game's own ability words."),
		{"kind": ICONS, "entries": entries},
		_text("Other keywords in this game's card pool carry no badge and "
			+ "are simply written on the card: vigilance (attacking does "
			+ "not tap it), haste (it can attack and pay {T} the turn it "
			+ "arrives — the original called that Quick Draw), defender "
			+ "(it cannot attack, which is what makes a Wall a Wall), fear "
			+ "and unblockable. The Showcase shows you the text."),
	]}


static func _page_icons_protection() -> Dictionary:
	var names := {
		Mtg.ManaColor.W: "white", Mtg.ManaColor.U: "blue",
		Mtg.ManaColor.B: "black", Mtg.ManaColor.R: "red",
		Mtg.ManaColor.G: "green",
	}
	var entries: Array = []
	for color in Mtg.WUBRG:
		var name_of: String = names[color]
		entries.append(_icon(
			"Protection from " + name_of,
			"A shield in " + name_of + ". It cannot be blocked by "
			+ name_of + " creatures; all damage dealt to it by a "
			+ name_of + " source is reduced to 0; and it cannot be the "
			+ "target of " + name_of + " spells or effects.",
			{"src": SRC_BADGE, "slot": MiniCard.PROTECTION_SLOT[color]},
			name_of.substr(0, 1).to_upper(), 32.0))
	entries.append(_icon("Protection from artifacts",
		"A BROWN shield — the sixth one on the 1997 sheet, and the only "
		+ "protection that is not from a color. Artifact creatures cannot "
		+ "block it, damage from an artifact source is prevented, and no "
		+ "artifact can target it. Artifact Ward is the card that grants "
		+ "it.",
		{"src": SRC_BADGE, "slot": MiniCard.ARTIFACT_PROTECTION_SLOT},
		"A", 32.0))
	return {"title": "Icons — protection", "blocks": [
		_text("A shield badge means PROTECTION from a color. Each of the "
			+ "five is drawn in its own color, and one creature can wear "
			+ "several at once. A sixth shield, in brown, means protection "
			+ "from ARTIFACTS."),
		{"kind": ICONS, "entries": entries},
		_heading("What protection does not do"),
		_quote("Protection is not immunity; the creature is still "
			+ "vulnerable to non-targeted, non-damage-dealing effects. For "
			+ "example, Wrath of God (a white spell that buries all "
			+ "creatures) will bury a creature with protection from white. "
			+ "Protection cannot prevent a creature from being sacrificed.",
			"manual p.179, Glossary"),
		_text("One more consequence worth knowing: giving a creature "
			+ "protection from a color destroys any enchantment of that "
			+ "color already on it, because the creature has stopped being "
			+ "a legal thing for that enchantment to be attached to."),
	]}


static func _page_icons_small_card() -> Dictionary:
	return {"title": "Icons — the small card", "blocks": [
		_text("Cards in play are drawn as SMALL CARDS — the original's own "
			+ "word for them. These are the marks you can meet on one. The "
			+ "quoted names are the game's own cue cards, from the table "
			+ "`@CUECARD_SMALLCARD`, which lists ten states a card on the "
			+ "table can be in. Rest the pointer on a card to read the ones "
			+ "it is wearing."),
		{"kind": ICONS, "entries": [
			_icon("Summoning sickness — a spiral",
				"Cue card: \"Summoning sickness\". Drawn over the art of a "
				+ "creature that has not been under your control since the "
				+ "start of your turn. It cannot attack and cannot pay a "
				+ "{T} cost. It CAN block, and it can use abilities that do "
				+ "not need {T}.",
				{"src": SRC_SPRITE, "key": "summon_sick"}, "spiral", 46.0),
			_icon("Damage marker — a dagger and a number",
				"Cue card: \"Damage: %d\". How much damage is marked on "
				+ "this creature. When it reaches the creature's toughness "
				+ "the creature is destroyed. It is wiped in the cleanup "
				+ "step, so a creature soaks up its toughness again every "
				+ "turn it survives.",
				{"src": SRC_SPRITE, "key": "damage_marker"}, "dagger", 44.0),
			_icon("Dying — silver cracks across the card",
				"Cue card: \"Dying\". The card is about to go to the "
				+ "graveyard — the one moment a regeneration effect can "
				+ "still answer for it. You see it on a creature holding "
				+ "lethal damage while the damage step is open, and again "
				+ "for a moment over the square a destroyed card is swept "
				+ "from. A creature that regenerates never wears it.",
				{"src": SRC_SPRITE, "key": "state_dying"}, "cracks", 46.0),
			_icon("A crosshair — the card is a target",
				"Cue card: \"Is a target\". Something on the spell chain "
				+ "is aimed at this card. While you are choosing targets "
				+ "yourself, the same crosshair marks a card you have "
				+ "already picked, whose cue card reads \"Is a target, "
				+ "can't target again\".",
				{"src": SRC_SPRITE, "key": "target_cursor"}, "target", 40.0),
			_icon("An orange circle-slash — you cannot aim at this",
				"Cue card: \"Can't target this\". Shown while you are "
				+ "choosing targets, on a card the spell or ability in "
				+ "hand refuses — the wrong color, the wrong type, "
				+ "protection, or a card that simply cannot be targeted at "
				+ "all.",
				{"src": SRC_SPRITE, "key": "state_cant_target"}, "no", 40.0),
			_icon("A blue arrow — the card will untap",
				"Cue card: \"This card will untap\". It is tapped and "
				+ "nothing is holding it down, so it comes back at its "
				+ "controller's next untap step. Its absence on a tapped "
				+ "card is the news: something — a Meekstone, a Paralyze — "
				+ "is keeping it that way.",
				{"src": SRC_SPRITE, "key": "state_will_untap"}, "untap", 34.0),
			_icon("'stolen' — the card is not controlled by its owner",
				"Cue card: \"Card is not controlled by owner\". Somebody "
				+ "has taken it — Control Magic, Steal Artifact — so it "
				+ "sits in a territory that is not its owner's. It is the "
				+ "one state on the original's list with no picture of its "
				+ "own, so it is lettered rather than drawn.",
				{"src": SRC_DRAWN}, MiniCard.NOT_OWNED_MARK),
			_icon("Activation cost — a mana symbol at the bottom-left",
				"This card has an ability you can pay to use, and this is "
				+ "the cost. The Showcase lists every ability in full; the "
				+ "badge is the reminder that there is one.",
				{"src": SRC_MANA, "sym": "2"}, "{2}"),
			_icon("Tapped — the card lies sideways",
				"It has been used this turn and carries a small (T). It "
				+ "untaps at the start of its controller's next turn. A "
				+ "tapped creature can neither attack nor block; a tapped "
				+ "non-creature artifact stops working entirely.",
				{"src": SRC_DRAWN}, MiniCard.TAPPED_MARK),
			_icon("An aura steps out from behind the card",
				"Every enchantment attached to a card is drawn as a WHOLE "
				+ "card behind it, stepped up and to the right so its "
				+ "title bar shows — the furthest one first, the card "
				+ "itself on top. Each one is separately hoverable and "
				+ "clickable, so you can read any of them in the Showcase.",
				{"src": SRC_DRAWN}, "aura"),
			_icon("A yellow name",
				"The card's name is drawn YELLOW when you could cast or use "
				+ "it right now, and WHITE when you could not. It also "
				+ "turns yellow under the pointer.",
				{"src": SRC_DRAWN}, "Aa"),
		]},
	]}


static func _page_icons_stripes() -> Dictionary:
	var stripe_names := {
		Mtg.ManaColor.W: "white", Mtg.ManaColor.U: "blue",
		Mtg.ManaColor.B: "black", Mtg.ManaColor.R: "red",
		Mtg.ManaColor.G: "green", Mtg.ManaColor.C: "colorless",
	}
	var stripes: Array = []
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
			Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
		var name_of: String = stripe_names[color]
		stripes.append(_icon("Mana stripe — " + name_of,
			"A slash in this place on the title bar means the card can be "
			+ "tapped for " + name_of + " mana.",
			{"src": SRC_STRIPE, "color": color},
			name_of.substr(0, 1).to_upper(), 30.0))
	return {"title": "Icons — the mana stripes", "blocks": [
		_text("A diagonal slash across a card's title bar means the card "
			+ "produces mana of that color. It is the fastest way to read "
			+ "your own lands at a glance without enlarging any of them."),
		_text("Every color owns a FIXED PLACE along the bar, left to right "
			+ "in the order below, so a card that makes several colors "
			+ "shows several slashes at once, each in its own slot — Black "
			+ "Lotus wears all five."),
		{"kind": ICONS, "entries": stripes},
		_text("A card with no stripe at all produces no mana. That includes "
			+ "the handful of lands that do something else entirely, which "
			+ "is worth remembering when you count your mana."),
	]}


static func _page_icons_phase_bar() -> Dictionary:
	var meaning: Array[String] = [
		"Everything of yours untaps, all at the same moment, and "
			+ "summoning sickness wears off. Neither player can act.",
		"Anything that happens 'during upkeep', including costs a card "
			+ "demands of you. The phase will not end until they are done.",
		"You draw your card for the turn. Both players may act before "
			+ "and after it.",
		"The first part of your main phase: play your land, cast what "
			+ "you like, and decide whether to attack.",
		"Combat. Clicking here announces that you intend to attack; the "
			+ "Combat Bar then replaces this bar until the attack is over.",
		"The rest of your main phase, after combat. If you have not "
			+ "played a land yet, you still can.",
		"If you hold more than seven cards you discard down to seven. "
			+ "Fast effects are allowed before the discard, not after.",
		"Damage is wiped and until-end-of-turn effects expire, together. "
			+ "The manual notes the curiosity that there is an icon here "
			+ "even though nobody can act during it (p.117).",
	]
	var entries: Array = []
	for slot in PhaseBar.SLOTS:
		entries.append(_icon(PhaseBar.CUE_YOURS[slot], meaning[slot],
			{"src": SRC_PHASE, "slot": slot}, str(slot + 1), 40.0))
	return {"title": "Icons — the Phase Bar", "blocks": [
		_quote("The Phase Bar, which runs from top to bottom of the screen "
			+ "just to the left of the territories, is the central control "
			+ "for the progress of the duel… First and foremost, the "
			+ "current phase is always highlighted. The top half of the bar "
			+ "represents the phases in your opponent's turn, while the "
			+ "lower half represents your turn.",
			"Duel.hlp, topic \"Phase Bar\""),
		_text("Sixteen icons in all, eight per player. The names below are "
			+ "the original's own cue cards — what pops up when you rest "
			+ "the pointer on an icon — for the lower, your-turn half."),
		{"kind": ICONS, "entries": entries},
	]}


static func _page_icons_phase_marks() -> Dictionary:
	return {"title": "The Phase Bar — running and stopping", "blocks": [
		_heading("The two marks on the bar"),
		{"kind": ICONS, "entries": [
			_icon("The lit icon — the current phase",
				"The phase you are in is drawn on a pale ground while the "
				+ "rest of the column stays dark. That highlight is the "
				+ "only thing marking the current phase.",
				{"src": SRC_PHASE, "slot": 3}, "▣", 40.0),
			_icon("A red dot — a Stop marker",
				"You have marked that phase to always stop. Right-click any "
				+ "icon and choose 'Mark this phase to always stop'; "
				+ "choosing it again takes the mark off. Stops are "
				+ "remembered between duels, and you can set them on either "
				+ "half of the bar — yours and your opponent's.",
				{"src": SRC_DRAWN}, "●"),
		]},
		_heading("Running to a phase"),
		_text("Left-clicking an icon RUNS to that phase: the duel skips "
			+ "forward without pausing on the way. It pauses anyway if "
			+ "something needs doing, if your opponent does something you "
			+ "could answer, or if it meets a Stop — and then your original "
			+ "destination is forgotten, because the situation has "
			+ "changed."),
		_heading("Why Stops exist"),
		_quote("Stop is another function of the Phase Bar. You can "
			+ "right-click on any phase and select Mark from the mini-menu "
			+ "to put a Stop marker on that phase. This is a lasting "
			+ "instruction that you do not want the duel to pass that phase "
			+ "until you have had a chance to do something.",
			"Duel.hlp, topic \"Stop\""),
		_quote("In Shandalar, there is no way to \"back up\" a phase. Thus, "
			+ "if a situation arises in which you would normally say to "
			+ "your opponent, \"Wait a minute. Before the end of that "
			+ "phase, I want to use a fast effect,\" you must prepare for "
			+ "that ahead of time. This is what Stops are designed for.",
			"Duel.hlp, topic \"Stop\""),
		_quote("Stops are especially necessary for those fast effects that "
			+ "must be used before combat begins. Once the Combat "
			+ "sub-phase begins, it is too late to use these effects. A "
			+ "Stop on your opponent's Main Pre-Combat sub-phase is always "
			+ "a good idea.", "Duel.hlp, topic \"Stop\""),
		_text("That last line is the single most useful piece of advice the "
			+ "1997 help file gives, and it is worth doing before your "
			+ "first serious duel."),
	]}


static func _page_icons_combat_bar() -> Dictionary:
	# `Duel.hlp`, topic "Combat Bar", names the seven sub-phases; the
	# entry NAMES here are `@CUECARD_PHASEBAR`'s last seven strings.
	var meaning: Array[String] = [
		"Declare Attackers. Choose which of your creatures attack — "
			+ "click each one. Your opponent can do nothing while you "
			+ "choose, and neither can you.",
		"Fast Effects. The attack is declared and your creatures are "
			+ "officially attacking creatures, so spells can target them. "
			+ "This is the last chance to make an attacker unblockable.",
		"Declare Blockers. The defending player puts blockers in front "
			+ "of attackers. The attacking player can do nothing here.",
		"Fast Effects (2). Blocks are in and the blockers can be "
			+ "targeted. This is where a combat trick belongs — it is the "
			+ "last chance before damage.",
		"Damage Dealing, Part 1: First Strike Damage Dealing. Skipped "
			+ "entirely when nobody in the combat has first strike.",
		"Damage Dealing, Part 2: Normal Damage Dealing. Everything else "
			+ "deals its damage, all at exactly the same time.",
		"Damage Dealing, Part 3: End of Combat. Anything that happens "
			+ "'at end of combat' takes place, the survivors go home, and "
			+ "your Main Post-Combat sub-phase begins.",
	]
	var entries: Array = []
	for slot in CombatBar.TOOLTIPS.size():
		entries.append(_icon(CombatBar.TOOLTIPS[slot], meaning[slot],
			{"src": SRC_COMBAT, "slot": slot}, str(slot + 1), 40.0))
	return {"title": "Icons — the Combat Bar", "blocks": [
		_quote("The Combat Bar is a miniature Phase Bar that appears during "
			+ "an attack. It functions in exactly the same way as the "
			+ "larger bar; you can even use Stops. This bar has seven "
			+ "icons, representing the sub-phases of combat.",
			"Duel.hlp, topic \"Combat Bar\""),
		_text("It takes the Phase Bar's place for as long as the attack "
			+ "lasts, and it wears the attacking side's color — BLUE when "
			+ "you are attacking, GOLD when your opponent is. The names "
			+ "below are its cue cards; each explanation opens with "
			+ "Duel.hlp's own name for that sub-phase."),
		{"kind": ICONS, "entries": entries},
		_text("The lit icon and the red Stop dots mean here exactly what "
			+ "they mean on the Phase Bar. While you are choosing attackers "
			+ "or blockers, clicking a sub-phase icon is a third way to say "
			+ "Done, beside the Done button and the mini-menu."),
	]}


static func _page_icons_table() -> Dictionary:
	var sets: Array = [
		_icon("Arabian Nights — a scimitar", "The first expansion of all, "
			+ "and where the ante cards come from.",
			{"src": SRC_SET, "code": "arn"}, "ARN"),
		_icon("Antiquities — an anvil", "The artifact set.",
			{"src": SRC_SET, "code": "atq"}, "ATQ"),
		_icon("Legends — a monument", "Legendary creatures, the banding "
			+ "cycles and the Elder Dragons.",
			{"src": SRC_SET, "code": "leg"}, "LEG"),
		_icon("The Dark — a crescent moon", "A small, grim expansion.",
			{"src": SRC_SET, "code": "drk"}, "DRK"),
		_icon("Fourth Edition — IV", "An all-reprint base set.",
			{"src": SRC_SET, "code": "4ed"}, "4ED"),
		_icon("Astral — a shooting star", "This game's OWN cards, made for "
			+ "it and found nowhere in paper Magic: Aswan Jaguar, Faerie "
			+ "Dragon, Gem Bazaar, Whimsy and the rest.",
			{"src": SRC_SET, "code": "past"}, "AST"),
	]
	return {"title": "Icons — around the table", "blocks": [
		{"kind": ICONS, "entries": [
			_icon("The targeting cursor",
				"The pointer becomes this while a spell or effect is asking "
				+ "what to aim at. Click a card — or a life register, to "
				+ "target that player. Escape cancels.",
				{"src": SRC_CURSOR}, "✛", 48.0),
			_icon("The window icon",
				"Cue card: \"Minimized attack window\". It appears in the "
				+ "blank band in the middle of the Phase Bar once you have "
				+ "minimised the Combat window from its top-right corner. "
				+ "Click it to bring the window back.",
				{"src": SRC_TEXTURE, "key": "attack_min"}, "▭", 28.0),
		]},
		_heading("Card set icons"),
		_text("Every card shows which set it came from, at the right-hand "
			+ "end of its type line. Six of this game's eight sets have a "
			+ "symbol. Unlimited and the promotional cards never had one "
			+ "printed, so those two are lettered instead — 2nd, 4th and "
			+ "PR — exactly as the printed cards leave them blank."),
		{"kind": ICONS, "entries": sets},
	]}


static func _page_icons_builder_colors() -> Dictionary:
	var glyphs := {
		Mtg.ManaColor.W: "a burst of light", Mtg.ManaColor.U: "a water drop",
		Mtg.ManaColor.B: "a skull", Mtg.ManaColor.R: "a dragon",
		Mtg.ManaColor.G: "a tree",
	}
	var colors: Array = []
	for color in DeckFilter.COLOR_ORDER:
		var label: String = DeckFilter.COLOR_LABELS[color]
		colors.append(_icon(label + " — " + String(glyphs[color]),
			"Cue card: \"" + DeckFilter.cue_card(label, true) + "\".",
			{"src": SRC_FILTER, "row": FilterBar.COLOR_CELL[color][0],
				"col": FilterBar.COLOR_CELL[color][1]}, label.substr(0, 1)))
	colors.append(_icon("Gold — five dots in a ring",
		"Cue card: \"Gold cards are in the list\". The sixth Color Filter: "
		+ "cards that need more than one color to cast. Right-click it for "
		+ "its own mini-menu — all gold cards, or only those matching all, "
		+ "or any, of the colors you have left on.",
		{"src": SRC_FILTER, "row": FilterBar.GOLD_CELL[0],
			"col": FilterBar.GOLD_CELL[1]}, "Au"))
	return {"title": "Icons — the Deck Builder: the filter strip", "blocks": [
		_quote("Between the Inventory and Deck areas are four sets of "
			+ "Filter buttons. These determine which cards are displayed in "
			+ "the inventory. Every one of these buttons is a toggle "
			+ "switch; when the button is depressed, it is on, and the "
			+ "cards that correspond to that filter are displayed.",
			"Duel.hlp, topic \"Filters\""),
		_text("So the builder opens with everything ON and you narrow it "
			+ "down by switching things off. A medallion that is ON is the "
			+ "plain one; one that is OFF is drawn dark and sunken. All of "
			+ "them live on a single row — Color, Set, Type and Other "
			+ "Filters in that order, told apart only by a wider gap."),
		_text("THE GOLD RING is the thing to learn: every SET medallion "
			+ "wears one and no other button does. That is what tells The "
			+ "Dark's crescent moon (ringed) from the Enchantments type "
			+ "filter's crescent moon (not ringed)."),
		_heading("Color Filters"),
		_text("The five colors are the only medallions drawn as a colored "
			+ "glyph on a BLACK disc, which is how you pick them out of the "
			+ "row. There is no filter for colorless cards: lands and "
			+ "artifacts have no color, so reach those through the Type "
			+ "Filters instead."),
		{"kind": ICONS, "entries": colors},
	]}


static func _page_icons_builder_sets() -> Dictionary:
	var set_glyphs := {
		"arn": "a scimitar", "atq": "an anvil", "leg": "a monument",
		"drk": "a crescent moon", "4ed": "IV", "past": "a shooting star",
	}
	var set_entries: Array = []
	for code in ["arn", "atq", "leg", "drk", "4ed", "past"]:
		var label: String = DeckFilter.SET_LABELS[code]
		set_entries.append(_icon(label + " — " + String(set_glyphs[code]),
			"Cue card: \"" + DeckFilter.cue_card(label, true) + "\".",
			{"src": SRC_FILTER, "row": FilterBar.SET_CELL[code][0],
				"col": FilterBar.SET_CELL[code][1]},
			GameSkin.set_label(code)))
	return {"title": "Icons — the Deck Builder: the sets", "blocks": [
		_quote("The leftmost set of filter buttons correspond to the sets "
			+ "of cards available. These are based on the various basic and "
			+ "expansion card sets released by Wizards of the Coast over "
			+ "time.", "Duel.hlp, topic \"Set Filters\""),
		_text("One button per set in the card pool, each wearing the gold "
			+ "ring that marks a set medallion. The cards themselves carry "
			+ "a plainer drawing of the same symbol at the end of their "
			+ "type line — those are on the 'around the table' page."),
		{"kind": ICONS, "entries": set_entries},
		_text("Unlimited and the promotional cards are lettered — 2nd and "
			+ "PR — rather than drawn, for the same reason their cards are: "
			+ "the original drew no symbol for either."),
		_quote("Astral, a card set created specifically for the MicroProse "
			+ "version of Magic: The Gathering, reflects the unusual nature "
			+ "of the plane of Shandalar.",
			"Duel.hlp, topic \"Set Filters\""),
		_heading("One more mark, in the Deck area"),
		{"kind": ICONS, "entries": [
			_icon("A number on a dark disc",
				"How many copies of that card your deck holds. It appears "
				+ "from the second copy onwards, on the card itself.",
				{"src": SRC_DRAWN}, "3"),
		]},
	]}


static func _page_icons_builder_types() -> Dictionary:
	var type_help := {
		Mtg.CardType.LAND: "A range of hills. Right-click for its three "
			+ "exclusive options — Land and Mana, Land only, or Mana only: "
			+ "the button reaches every mana source, not only lands.",
		Mtg.CardType.ARTIFACT: "A chalice. Right-click to tick All "
			+ "Creatures and All Non-Creatures, which are independent of "
			+ "each other.",
		Mtg.CardType.CREATURE: "A bat. Anything with a power and a "
			+ "toughness.",
		Mtg.CardType.ENCHANTMENT: "A crescent moon with NO gold ring — the "
			+ "ringed crescent two places along is The Dark. Lasting magic, "
			+ "local or global.",
		Mtg.CardType.INSTANT: "A lightning bolt. Castable at almost any "
			+ "time, including on your opponent's turn.",
		Mtg.CardType.SORCERY: "A hooded sorcerer. Castable only in your "
			+ "own main phase.",
	}
	var types: Array = []
	for type_flag in DeckFilter.TYPE_ORDER:
		var label: String = DeckFilter.TYPE_LABELS[type_flag]
		types.append(_icon(label,
			"Cue card: \"" + DeckFilter.cue_card(label, true) + "\". "
			+ String(type_help[type_flag]),
			{"src": SRC_FILTER, "row": FilterBar.TYPE_CELL[type_flag][0],
				"col": FilterBar.TYPE_CELL[type_flag][1]},
			label.substr(0, 2)))
	var other: Array = [
		_icon("Casting cost — an X",
			"Cue card: \"" + DeckFilter.filtered_by_cue_card("cast cost", true)
			+ "\". Right-click to choose the comparison and the number: "
			+ "greater than or equal to, less than or equal to, equal to, "
			+ "or X cost. It treats a mana cost as one simple total, "
			+ "whatever the colors.",
			{"src": SRC_FILTER, "row": FilterBar.COST_CELL[0],
				"col": FilterBar.COST_CELL[1]}, "X"),
		_icon("Power — a sword",
			"Cue card: \"" + DeckFilter.filtered_by_cue_card("power", true)
			+ "\". Ranks creatures by attack strength. Right-click for the "
			+ "comparison and the number.",
			{"src": SRC_FILTER, "row": FilterBar.POWER_CELL[0],
				"col": FilterBar.POWER_CELL[1]}, "P"),
		_icon("Toughness — a quartered shield",
			"Cue card: \"" + DeckFilter.filtered_by_cue_card("toughness", true)
			+ "\". The same, for how much damage a creature can absorb.",
			{"src": SRC_FILTER, "row": FilterBar.TOUGHNESS_CELL[0],
				"col": FilterBar.TOUGHNESS_CELL[1]}, "T"),
	]
	return {"title": "Icons — the Deck Builder: types and other filters",
		"blocks": [
		_heading("Type Filters"),
		{"kind": ICONS, "entries": types},
		_quote("You can also right-click on some of the filter buttons to "
			+ "open a mini-menu of options. These represent sub-groups of "
			+ "that filter.", "Duel.hlp, topic \"Filters\""),
		_heading("Other Filters"),
		{"kind": ICONS, "entries": other},
		_text("The original's Other Filters group had six buttons. Three of "
			+ "them — Ability, Rarity and Artist — are not built here, "
			+ "because the card data this remake loads cannot answer them "
			+ "yet, and a filter that quietly does nothing is worse than a "
			+ "missing one."),
	]}


# ------------------------------------------------------------ the icons --

## The texture for one icon spec, fetched through THE SAME accessor the
## screen being documented draws it with — so an index that drifts breaks
## this and the screen together. Null when the 1997 skin is absent, when
## the spec is code-drawn, or when the source is unknown; the screen falls
## back to the entry's `alt` string in every one of those cases.
static func icon_texture(spec: Dictionary) -> Texture2D:
	match String(spec.get("src", "")):
		SRC_MANA:
			return ManaIcons.symbol(String(spec.get("sym", "")))
		SRC_BADGE:
			return MiniCard.badge_from_slot(int(spec.get("slot", -1)))
		SRC_STRIPE:
			return MiniCard.stripe_texture(int(spec.get("color", 0)))
		SRC_SPRITE:
			return MiniCard.masked_sprite(String(spec.get("key", "")))
		SRC_TEXTURE:
			return GameSkin.texture(String(spec.get("key", "")))
		SRC_PHASE:
			# The HIGHLIGHTED cell. The sheet draws it on a pale ground,
			# which is the legible one to show at rest on a stone page —
			# and it is what the bar itself shows for the current phase.
			return GameSkin.region("phase_bar", Rect2i(PhaseBar.active_region(
				PhaseStops.Half.YOURS, int(spec.get("slot", 0)))))
		SRC_COMBAT:
			return GameSkin.region("combat_bar", Rect2i(
				CombatBar.active_region(true, int(spec.get("slot", 0)))))
		SRC_FILTER:
			# The PLAIN sheet — which, since the 2026-08-31 screenshot pass
			# re-read the original, is the ON state: a filter that is on is
			# the plain medallion and one that is off is the dark sunken
			# one. That is how the builder opens and how the player first
			# meets each button (`FilterBar._paint_icon`).
			return FilterBar.sheet_cell("filter_icons",
				int(spec.get("row", -1)), int(spec.get("col", -1)))
		SRC_SET:
			return GameSkin.set_icon(String(spec.get("code", "")))
		SRC_CURSOR:
			# Target.pic is a strip of square frames; the duel screen shows
			# the first one as the cursor, and so does this.
			var sheet := GameSkin.texture("target_cursor")
			if sheet == null:
				return null
			var side := sheet.get_height()
			return GameSkin.region("target_cursor", Rect2i(0, 0, side, side))
	return null


## Every icon entry on every page, flat — the inventory the tests walk.
static func icon_entries() -> Array:
	var out: Array = []
	for page in pages():
		for block in page["blocks"]:
			if String(block.get("kind", "")) == ICONS:
				out.append_array(block["entries"])
	return out


## Every word the reference shows, as one string. Tests search it; nothing
## in the game reads it.
static func all_text() -> String:
	var parts := PackedStringArray()
	for page in pages():
		parts.append(String(page.get("title", "")))
		for block in page["blocks"]:
			parts.append(String(block.get("text", "")))
			parts.append(String(block.get("cite", "")))
			for entry in block.get("entries", []):
				parts.append(String(entry.get("name", "")))
				parts.append(String(entry.get("text", "")))
	return "\n".join(parts)


# --------------------------------------------------------- the builders --

static func _heading(text: String) -> Dictionary:
	return {"kind": HEADING, "text": text}


static func _text(text: String) -> Dictionary:
	return {"kind": TEXT, "text": text}


static func _quote(text: String, cite: String) -> Dictionary:
	return {"kind": QUOTE, "text": text, "cite": cite}


## One icon entry. [param alt] is what stands in for the picture when the
## 1997 skin is not imported, so the reference still reads without it.
static func _icon(name: String, text: String, icon: Dictionary, alt: String,
		size := 34.0) -> Dictionary:
	return {"name": name, "text": text, "icon": icon, "alt": alt, "size": size}


## An ability badge, addressed by the KEYWORD the mini card draws it for —
## so the entry cannot drift from [constant MiniCard.BADGE_SLOT].
static func _badge_icon(keyword: int, name: String, text: String) -> Dictionary:
	return _icon(name, text,
		{"src": SRC_BADGE, "slot": MiniCard.BADGE_SLOT[keyword]},
		name.substr(0, 1), 32.0)

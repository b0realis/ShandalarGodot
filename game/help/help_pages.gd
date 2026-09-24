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
## Legacy QUOTE blocks retain source metadata for maintenance, but the
## player sees facts only. Source references belong in developer material.
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
## **5. Teach only verified, playable behavior.** Do not display development
## archaeology, source citations or speculation in the player's reference.

# ------------------------------------------------------------ the shape --

## Block kinds a page may contain.
const HEADING := "heading"     ## A section title inside a page.
const TEXT := "text"           ## Our own prose.
const QUOTE := "quote"         ## A sourced quotation: `text` + `cite`.
const ICONS := "icons"         ## A list of `entries` (see below).
const CARDS := "cards"         ## Live in-game card examples with captions.
const KINDS: Array[String] = [HEADING, TEXT, QUOTE, ICONS, CARDS]

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
const SRC_SET := "set"         ## `code`, optional `rarity`/`legendary` — a set symbol.
const SRC_CURSOR := "cursor"   ## the targeting cursor.
const SRC_COUNTER := "counter" ## `row` — one counter stone off the 1997 strip.
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
		_page_icons_counters(),
		_page_icons_counters_more(),
		_page_icons_stripes(),
		_page_icons_phase_bar(),
		_page_icons_phase_marks(),
		_page_icons_combat_bar(),
		_page_icons_table(),
		_page_builder(),
		_page_icons_builder_colors(),
		_page_icons_builder_sets(),
		_page_icons_builder_types(),
	] + preload("res://game/help/ability_glossary.gd").pages()


# ---------------------------------------------------------- the primer --

## Player primer, revised after the 2026-09-13 playtest. Rules provenance
## remains in the engine and repository documentation; pages teach play.
static func _page_duel() -> Dictionary:
	return {"title": "The Duel", "blocks": [
		_heading("Build your mana. Play your cards. Defeat the other wizard."),
		_text("Both players normally start at 20 life. Use creatures, spells and abilities to bring your opponent to 0 while protecting yourself."),
		_cards([
			["Forest", "1 · Make mana", "Play a land during your main phase. Tap it to produce mana for your spells."],
			["Grizzly Bears", "2 · Build your battlefield", "Spend mana to cast creatures. They can block immediately, but usually must wait until your next turn to attack."],
			["Lightning Bolt", "3 · Choose your moment", "Attack with creatures or cast spells. An instant can answer a threat on either player's turn when you have priority."],
		]),
		_heading("Three ways to lose"),
		_text("Life reaches 0 or less · You must draw from an empty library · You have ten poison counters. The negative-life option changes when life is checked."),
		_heading("Read the card"),
		_text("A card's instructions can override the usual rules. Hover over it to read the enlarged card and its current state."),
	]}


static func _page_table() -> Dictionary:
	return {"title": "The Dueling Table", "blocks": [
		_heading("Your opponent above · Your cards below"),
		_text("The upper territory belongs to your opponent; the lower territory is yours. Attacking and blocking creatures move into the combat window."),
		_cards([["Serra Angel", "Showcase", "Hover over a face-up card to enlarge it. The Showcase displays the printed card; the small battlefield card shows current stats."]]),
		{"kind": ICONS, "entries": [
			_icon("Mana pool", "Mana produced but not spent appears beside your life register. Click a player's life register when a spell asks you to target that player.", {"src": SRC_MANA, "sym": "G"}, "{G}"),
			_icon("Phase Bar", "The highlighted icon shows the current phase. Add a red Stop where you want the duel to wait for you.", {"src": SRC_PHASE, "slot": 3}, "Phase"),
		]},
		_heading("The prompt tells you what to do next"),
		_text("The Situation Bar asks for attackers, blockers, targets or mana. Done completes the current choice. Cancel abandons a choice when that is still allowed."),
		_heading("Keep these keys handy"),
		_text("%s: Done · %s: Cancel · %s: press the sole available action button. On a controller %s is that button, %s is Done, %s is Cancel and %s opens the pause menu. Change any of them under Options, Controls. Right-click cards and table areas for their menus." % [
			Controls.key_text("duel_done"), Controls.key_text("duel_cancel"), Controls.key_text("duel_space"),
			Controls.pad_text("duel_space"), Controls.pad_text("duel_done"), Controls.pad_text("duel_cancel"),
			Controls.pad_text("duel_pause")]),
		_heading("Hand, library and graveyard"),
		_text("Your hand holds cards you can play. The face-down library supplies draws. Click either graveyard to inspect discarded cards; the menu also gives access to exile."),
		_heading("Hotseat · Take turns privately"),
		_text("Player 1 uses the lower playfield; Player 2 uses the upper one. Names carry (below) or (above). Drag either hand stack by its title bar; both buttons move with it. Press Show hand when the other player looks away. Hide hand (or H) conceals it again. The other hand shows only its card count. Opening hands and mulligans use the same Show/Hide button. The opening screen gives one privacy reminder; during the duel, the Situation Bar names the player who must act and keeps the phase or choice instruction visible."),
		_heading("Hotseat · Let your opponent respond"),
		_text("The turn player keeps control through routine phases. Before pressing Done, give your opponent time to say they want to respond. Press Opponent below Show/Hide to hand over; the other player reveals their hand and can cast an instant or use an ability. Their Done returns control. This shortcut assumes the silent opponent passes: it cannot rewind an action already resolved. Blockers, combat-damage assignments and required card choices still hand over automatically. Every handover and new turn hides both hands."),
		_heading("Demo · Watch both players"),
		_text("In AI-versus-AI games, both players have matching draggable hand stacks. Both hands stay openly visible throughout the duel, including responses and turn changes. Watching a hand does not let you play its cards."),
	]}


static func _page_mana() -> Dictionary:
	return {"title": "Mana — the fuel of every spell", "blocks": [
		_heading("Lands make mana; mana pays costs"),
		_cards([["Forest", "Tap a land", "Click an untapped Forest to add one green mana. The land turns sideways and normally untaps at the start of your next turn."],
			["Llanowar Elves", "Other cards make mana too", "These Elves can tap for green mana. Unlike an ordinary land, a creature with a tap ability must wait until it is no longer summoning-sick, unless it has haste."]]),
		_heading("Reading the symbols"),
		{"kind": ICONS, "entries": [
			_icon("A colored symbol", "Each {G} requires one green mana. The other four colors work the same way.", {"src": SRC_MANA, "sym": "G"}, "{G}"),
			_icon("A number", "A generic cost can be paid with any type of mana. {2}{W}{W} needs two white mana and two more mana of any type.", {"src": SRC_MANA, "sym": "2"}, "{2}"),
		]},
		_text("{X} is an amount you choose while casting. {T} is a tap cost: turn that permanent sideways to pay it."),
		_heading("Spend it before it empties"),
		_text("Mana does not carry into the next step under modern pool timing. The 1997 timing option empties pools at phase boundaries instead. Mana burn is on by default: lose 1 life for each unspent mana when the pool empties. You can change either option in Settings."),
	]}


static func _page_colors() -> Dictionary:
	return {"title": "The five colors of magic", "blocks": [
		_heading("Five lands · Five colors"),
		{"kind": ICONS, "entries": [
			_icon("White · Plains", "Healing, protection and organized armies.", {"src": SRC_MANA, "sym": "W"}, "{W}"),
			_icon("Blue · Island", "Card drawing, countermagic and flying creatures.", {"src": SRC_MANA, "sym": "U"}, "{U}"),
			_icon("Black · Swamp", "Destruction, discard and power bought at a price.", {"src": SRC_MANA, "sym": "B"}, "{B}"),
			_icon("Red · Mountain", "Direct damage, aggressive creatures and destruction.", {"src": SRC_MANA, "sym": "R"}, "{R}"),
			_icon("Green · Forest", "Large creatures, mana growth and combat boosts.", {"src": SRC_MANA, "sym": "G"}, "{G}"),
		]},
		_heading("Color is not the same as mana production"),
		_text("Most lands are colorless even when they make colored mana. A color-changing spell changes an object's color, not its land types or the mana it produces. Colorless is not a sixth color."),
		_text("A card can have more than one color. Colored symbols in its mana cost normally determine those colors; effects can change them during a duel."),
	]}


static func _page_card() -> Dictionary:
	return {"title": "The parts of a card", "blocks": [
		_cards([["Serra Angel", "Name → cost → type → rules → power/toughness", "The name is at the top, the mana cost at top right, and the type line below the art. Read the rules box for abilities. The bottom-right 4/4 means 4 power and 4 toughness."]]),
		_heading("Printed card and current creature"),
		_text("The Showcase shows the printed card. The small battlefield card shows its current power/toughness: green when boosted, red when weakened, and cyan when a non-creature card has become a creature. Damage is a separate dagger and number; it does not subtract from the displayed toughness."),
		_heading("Cost : effect"),
		_text("An activated ability has a colon. Pay everything before it to get the effect after it. A yellow card name indicates an available action; click a permanent to choose an ability."),
		_heading("Art is not a rule"),
		_text("A creature flies only if its rules give it flying. Its illustration, flavor text and artist credit do not change what it can do."),
	]}


static func _page_card_kinds() -> Dictionary:
	return {"title": "The kinds of card", "blocks": [
		_cards([["Swamp", "Land", "Usually one land play per turn, in your main phase with an empty Spell Chain. Playing a land does not use the chain."],
			["Grizzly Bears", "Creature", "A permanent that can attack and block. Summoning sickness prevents attacking and paying tap costs until your next turn, unless it has haste."],
			["Sol Ring", "Artifact", "A permanent with its own abilities. Some artifacts are also creatures; they follow both sets of rules."],
			["Unholy Strength", "Enchantment / Aura", "An enchantment stays on the battlefield. An Aura is attached to the object it enchants."],
			["Fireball", "Sorcery", "Cast during your main phase, with an empty chain. It resolves, then goes to the graveyard."],
			["Lightning Bolt", "Instant", "Cast on either player's turn whenever you have priority, including the fast-effects windows in combat."]]),
		_heading("Where a finished card goes"),
		_text("Used spells, discarded cards and destroyed permanents normally go to their owner's graveyard. Exile is a separate zone; moving a creature there is not destroying it."),
	]}


static func _page_turn() -> Dictionary:
	var entries: Array = []
	var names := ["Untap", "Upkeep", "Draw", "Main Pre-Combat", "Combat", "Main Post-Combat", "Discard", "Cleanup"]
	var hints := ["Untap your permanents and begin your turn.", "Resolve upkeep effects and payments; the first chance to use fast effects.", "Draw a card, then use fast effects if you wish.", "Play a land and cast spells while the chain is empty.", "Declare attackers, declare blockers, use combat tricks, then deal damage.", "Another chance to play your land or cast spells before ending the turn.", "Discard down to your maximum hand size, normally seven.", "Remove marked damage and end until-end-of-turn effects."]
	for i in names.size():
		entries.append(_icon("%d · %s" % [i + 1, names[i]], hints[i], {"src": SRC_PHASE, "slot": i}, str(i + 1)))
	return {"title": "The turn and its phases", "blocks": [
		{"kind": ICONS, "entries": entries},
		_heading("Stops keep a window open"),
		_text("Mark a phase with a red Stop to wait there. Required choices always stop play. A payable fast effect holds the combat windows after attackers and blockers are declared."),
	]}


static func _page_casting() -> Dictionary:
	return {"title": "Casting spells and the Spell Chain", "blocks": [
		_cards([["Lightning Bolt", "1 · Choose a spell", "Click the spell in your hand. Double-click to use automatic mana payment; you still choose its targets."],
			["Grizzly Bears", "2 · Choose a legal target", "For a card target, click the card. To target a player, click their life register. A spell without a legal required target cannot be cast."],
			["Counterspell", "3 · Give both players a chance to respond", "Spells and abilities wait on the Spell Chain. When both players pass, the newest item resolves first. Then both players get another chance to act."]]),
		_heading("Paying manually"),
		_text("When the prompt asks for mana, click your mana sources to pay. A tap ability cannot use an already-tapped permanent. Cancel before submitting if you want to abandon the spell."),
		_heading("Targets are checked again"),
		_text("A spell or ability with no legal targets left does not resolve. A creature with protection can make a matching colored target illegal. Not all effects target: an effect that affects all creatures can still affect protected ones."),
	]}


static func _page_combat() -> Dictionary:
	return {"title": "Combat", "blocks": [
		_cards([["Hill Giant", "1 · Choose attackers", "Click the creatures you want to attack with, then Done. Attacking usually taps them. You attack the other player, not their creatures. A creature that can band with an attacker already chosen is asked \"Band with which attacker?\" — click that attacker to form the band, or click the creature again to attack alone. A band stands in one blue frame in the Combat window."],
			["Grizzly Bears", "2 · Choose blockers", "Click your blocker, then the attacker it should block. Repeat, then Done. Several creatures can block the same attacker."],
			["Will-o'-the-Wisp", "3 · Use fast effects before damage", "After blocks are declared, use instants and activated abilities. With modern damage timing, buy regeneration now: click the creature, select its regeneration ability, and pay the cost."],
		]),
		_heading("4 · Assign and deal damage"),
		_text("When asked to divide damage, each click assigns one point. Cyan (ice-blue) dagger counts show the points assigned so far, including earlier groups. This is a damage preview, not a counter. Once all assignments are complete, damage is dealt; red damage counts show the damage actually marked on surviving creatures."),
		_text("The division is free: put each point on whichever blocker you like, in any order. With Free combat damage division switched off in Options, the 2009-2024 order applies: give the first blocker lethal damage before the next. Trample can put excess damage on the defending player after blockers have lethal assigned."),
		_heading("First strike and blocked attackers"),
		_text("First strike deals damage in an earlier step. A blocked attacker stays blocked even if its blockers leave combat; without trample it does not hit the player."),
	]}


static func _page_damage() -> Dictionary:
	return {"title": "Damage, death and regeneration", "blocks": [
		_cards([["Will-o'-the-Wisp", "Regeneration costs {B}", "Pay one black mana for a shield. The next time this creature would be destroyed this turn, it taps, clears its damage and leaves combat instead. Paying alone does not tap it or remove it from combat."],
			["Kormus Bell", "Animated lands are creatures too", "While the Bell's effect applies, Swamps are 1/1 black creatures as well as lands. Their cyan power/toughness shows the live size, including other bonuses. This is a continuous effect, not an activation."]]),
		_heading("Modern damage timing: act before the hit"),
		_text("After choosing blockers, press Done to enter the fast-effects window. Activate regeneration and let it resolve before you pass into combat damage. You cannot regenerate a creature that is already in the graveyard."),
		_heading("1997 damage prevention step: wait for the prompt"),
		_text("With Damage prevention step enabled, damage waits for prevention, healing and redirection. A regeneration window follows for creatures that would still be destroyed. Use regeneration there when the prompt asks for it."),
		_text("Reverse Damage protects you, not a creature. Jade Monolith can save a creature by redirecting its damage to you. In the classic window, Simulacrum and Reverse Polarity also recover damage from that window as it actually reaches you; prevented or redirected-away damage earns no life. In modern rules they count only damage already dealt when they resolve."),
		_heading("Read your active protection"),
		_text("A small shield on a player's portrait shows active damage effects. Click it for the source, what the effect does and its duration. The list updates as shields are used or expire, including online. Eye for an Eye mirrors damage; it does not prevent your damage."),
		_heading("What regeneration cannot save"),
		_text("Sacrifice, exile, toughness of 0 or less, and destruction that says it cannot be regenerated. Ordinary damage remains marked until cleanup and adds up across hits; reducing toughness is not damage."),
	]}


static func _page_start_finish() -> Dictionary:
	return {"title": "Starting and finishing a duel", "blocks": [
		_cards([["Forest", "Keep or redraw?", "Look for enough mana to cast your early spells. You may keep your opening hand or mulligan: redraw one fewer card each time."]]),
		_heading("Play or draw"),
		_text("The toss winner chooses who plays first. The first player skips their first draw step; the other player draws on their first turn."),
		_heading("Winning, losing and drawing"),
		_text("A player loses through life, poison, or an impossible required draw. If both players lose at the same time, the duel is a draw. Concede ends your duel after confirmation."),
		_heading("Ante and matches"),
		_text("Ante puts the chosen cards at stake for the duel. Review the ante setting before starting. In a match, the sideboard lets you change your deck between games while keeping the selected format legal."),
	]}


static func _page_ruleset() -> Dictionary:
	var blocks: Array = [
		_heading("Choose the rules before the duel"),
		_text("Options offers Modern rules, 1997 — Fifth Edition, or your own Custom combination. Mana burn is on by default; a saved choice is remembered."),
		{"kind": ICONS, "entries": [_icon("Mana burn", "Lose 1 life per unspent mana when your pool empties. Turn this off for the modern no-burn rule.", {"src": SRC_MANA, "sym": "B"}, "{B}")]},
	]
	for fork in RulesOptions.FORKS:
		blocks.append(_heading(String(fork["label"])))
		blocks.append(_text("1997: " + String(fork["fifth"])))
		blocks.append(_text("Modern: " + String(fork["modern"])))
	return {"title": "Which rules this game plays by", "blocks": blocks}


static func _page_formats() -> Dictionary:
	var blocks: Array = [
		_text("Choose a format on the battle setup screen. All five formats are enforced: both the main deck and sideboard are checked before the duel starts."),
		_cards([["Plains", "Basic lands are exempt", "Basic lands do not count toward copy limits, including Highlander's one-copy limit."]]),
	]
	for format in DeckFormat.ORDER:
		blocks.append(_heading(format))
		blocks.append(_text(DeckFormat.SUMMARY[format]))
	return {"title": "Deck formats — the five", "blocks": blocks}


static func _page_format_lists() -> Dictionary:
	CardRegistry.ensure_loaded()
	var restricted := PackedStringArray()
	var banned := PackedStringArray()
	for name in DeckFormat.RESTRICTED:
		if CardRegistry.has_card(name) and not restricted.has(name):
			restricted.append(name)
	for name in DeckFormat.BANNED:
		if CardRegistry.has_card(name) and not banned.has(name):
			banned.append(name)
	restricted.sort()
	banned.sort()
	return {"title": "Deck formats — the lists", "blocks": [
		_cards([["Black Lotus", "Restricted in Type 1", "At most one copy across your main deck and sideboard. Type 1.5 excludes restricted cards entirely."]]),
		_heading("Restricted cards in the card pool"),
		_text(", ".join(restricted)),
		_heading("Banned cards in the card pool"),
		_text(", ".join(banned)),
		_heading("Limits count both piles"),
		_text("Four Lightning Bolts in the main deck plus one in the sideboard is five copies. Unrestricted has no copy or list limits. Highlander permits one of each non-basic card without applying these lists."),
		_heading("The Restricted set filter is different"),
		_text("In the Deck Builder's set filters, Restricted names a group of treasure cards. It is not the tournament restricted list."),
	]}

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
		_text("Colorless mana has no symbol of its own — a card that makes "
			+ "it shows the amount as a plain number, the way the original "
			+ "wrote Sol Ring's 'Add {2}' and Apprentice Wizard's 'Add {3}'. "
			+ "It pays generic costs like any other mana, and nothing else. "
			+ "Your mana pool shows it in its own row, which the original's "
			+ "cue card names 'Your mana pool: amount of Colorless'."),
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
			+ "A band may also carry one creature without banding. "
			+ "The band is formed while choosing attackers: when a creature "
			+ "that can band with an attacker already chosen is added, the "
			+ "Situation Bar asks \"Band with which attacker?\" — click that "
			+ "attacker, or click the creature again to attack alone. "
			+ "A blocker with banding lets its controller divide the "
			+ "attacker's damage among that attacker's blockers."),
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


## THE COUNTER STONES, the owner's ask of 2026-09-09: *"Can you show me
## what individual counter stones mean? Also document this in help with
## pictures!"* Every stone is fetched BY CARD NAME out of
## [constant CounterMarks.TILE_BY_CARD] and by kind out of
## [constant CounterMarks.TILE_BY_KIND] — the very tables the small card
## picks its stone from — so a row that drifts breaks this page and the
## duel screen together, and no index is typed here at all. The wording
## quoted for each stone is its `@CUECARD_COUNTERS_*` line, [1997].
##
## It is TWO PAGES of its own rather than a block on the small-card page:
## that page already carries eleven marks, and this material is sixteen
## rows. One page held them all at 2174 px against a 618 px viewport —
## three and a half screens, half again as tall as the longest page the
## reference had (the Deck Builder's filters, 1567). Split at the
## headings, both halves land where the rest of the book already is.
##
## THE FAMILIES — the five Mana Batteries and the five lucky charms —
## are ONE ENTRY EACH, a strip of five stones ([method _icon_family]),
## because five rows differing only in color teach nothing five times.
## A family entry lives in a BLOCK OF ITS OWN; see that method. The strip
## is ours, [QoL] 2026-09-09; so is the note that the ankh stones can
## never appear in play, our lucky charms banking no `life` counters.
static func _page_icons_counters() -> Dictionary:
	return {"title": "Icons — the counter stones", "blocks": [
		_text("Some cards keep a running number on themselves: the +1/+1 a "
			+ "Fungusaur grows when something hurts it, the charge a Mana "
			+ "Battery stores, the corpses a Scavenging Ghoul eats. Those "
			+ "numbers are COUNTERS, and a card in play wears one small "
			+ "oval STONE for each KIND of counter on it, in a row just "
			+ "under its title bar, with the count in white beside it."),
		_text("The stone says WHICH counter, the number says HOW MANY, and "
			+ "resting the pointer on the card spells both out in the "
			+ "game's own words — \"Carrion counters: 2\". A stone belongs "
			+ "to the CARD rather than to the counter, which is why a "
			+ "Sengir Vampire's +1/+1 and a Rock Hydra's are not the same "
			+ "picture: the original handed out twenty-four stones by "
			+ "name, and those twenty-four are all there are."),
		_text("The original put down one stone for every single counter and "
			+ "let them overlap when the row ran out of room. Our cards on "
			+ "the table are smaller, and a Rock Hydra's six heads would "
			+ "be six smudges, so we draw ONE stone per kind and let the "
			+ "number do the counting."),
		_heading("Counters that change a creature"),
		_text("A yin-yang is a counter that changes a creature's power and "
			+ "toughness. A card that grows its own wears one in its own "
			+ "color; a counter put on a creature by something ELSE wears "
			+ "the color of whatever put it there."),
		{"kind": ICONS, "entries": [
			_icon("A green yin-yang — +1/+1",
				"Cue card: \"+1/+1 counters: 1\". Each one makes the "
				+ "creature one bigger in both directions for as long as it "
				+ "stays there. Fungusaur takes one every time it is dealt "
				+ "damage and lives; Citanul Druid takes one whenever an "
				+ "opponent casts an artifact; Whirling Dervish takes one "
				+ "at the end of any turn in which it hurt an opponent.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Fungusaur"]},
				"+1/+1", 44.0),
			_icon("A black yin-yang — +1/+1",
				"The same counter, on a black creature. Sengir Vampire "
				+ "takes one whenever a creature it damaged this turn "
				+ "dies; Khabál Ghoul takes one for every creature that "
				+ "died this turn, at the end of both players' turns.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Sengir Vampire"]},
				"+1/+1", 44.0),
			_icon("An olive yin-yang — +1/+1",
				"The artifact one, a dull olive rather than the Fungusaur "
				+ "stone's vivid green. Triskelion enters play with three "
				+ "of them, and each one you take off is a point of damage "
				+ "it shoots at anything you choose.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Triskelion"]},
				"+1/+1", 44.0),
			_icon("A red yin-yang — +1/+1, and -0/-1",
				"Rock Hydra's heads: it enters with X of them, and each 1 "
				+ "damage it would take pulls one off instead. It is also "
				+ "the stone EVERY OTHER +1/+1 wears here, because the "
				+ "engine does not remember which card put a counter down "
				+ "— Dwarven Weaponsmith's upkeep gift is this stone. So "
				+ "is the counter Orcish Catapult scatters, whose cue card "
				+ "reads \"Damage (-0/-1) counters\" and which takes a "
				+ "point of toughness rather than giving one.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Rock Hydra"]},
				"+1/+1", 44.0),
			_icon("The Tetravus — drones",
				"Cue card: \"Drone (+1/+1) counters\", and the stone is a "
				+ "picture of the machine itself. Tetravus enters with "
				+ "three; at your upkeep you may turn any number of them "
				+ "into 1/1 flying Tetravite tokens, and turn the tokens "
				+ "back into counters the same way.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Tetravus"]},
				"drone", 44.0),
			_icon("A gear — +1/+0",
				"Cue card: \"Clockwork (+1/+0) counters\". Clockwork Beast "
				+ "enters with seven and Clockwork Avian with four; each "
				+ "one is a point of power, and one comes off at the end "
				+ "of any combat the machine took part in. You can wind "
				+ "them back up during your upkeep. Time Vault does not "
				+ "use \"Turn counters\"; it untaps by skipping a turn.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Clockwork Beast"]},
				"+1/+0", 44.0),
			_icon("A pale yin-yang — -0/-2",
				"Cue card: \"Shackle (-0/-2) counters\", and it is Spirit "
				+ "Shackle's. The creature it enchants takes one every "
				+ "time it becomes tapped, and each one is two toughness "
				+ "gone: a 2/2 with one of these counters has 0 toughness "
				+ "and dies.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_KIND["-0/-2"]},
				"-0/-2", 44.0),
			_icon("A blue yin-yang — -1/-1",
				"Cue card: \"Mutation (-1/-1) counters\", and it is "
				+ "Unstable Mutation's. The aura hands the creature +3/+3 "
				+ "at once, then puts one of these on it at the start of "
				+ "every one of its controller's upkeeps until the bargain "
				+ "comes due.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_KIND["-1/-1"]},
				"-1/-1", 44.0),
		]},
		_text("The rest of the stones — the ones a permanent keeps count "
			+ "with, and the two families of five — are on the next page."),
	]}


## The second half; see [method _page_icons_counters] for why there are
## two. The families' strips are built here, where they are shown.
static func _page_icons_counters_more() -> Dictionary:
	# The two families, in the strip's own order, taken by card name.
	var batteries: Array = []
	for card_name in ["Black Mana Battery", "Blue Mana Battery",
			"Green Mana Battery", "Red Mana Battery", "White Mana Battery"]:
		batteries.append({"src": SRC_COUNTER,
			"row": CounterMarks.TILE_BY_CARD[card_name]})
	var charms: Array = []
	for card_name in ["Throne of Bone", "Crystal Rod", "Wooden Sphere",
			"Iron Star", "Ivory Cup"]:
		charms.append({"src": SRC_COUNTER,
			"row": CounterMarks.TILE_BY_CARD[card_name]})
	return {"title": "Icons — the counter stones, continued", "blocks": [
		_heading("Counters a permanent keeps for itself"),
		_text("These are tallies rather than sizes: the card counts "
			+ "something up and then spends it, and the number beside the "
			+ "stone is the whole of the information."),
		{"kind": ICONS, "entries": [
			_icon("A scythe — doom",
				"Cue card: \"Doom counters: 1\". Armageddon Clock puts one "
				+ "on itself at each of your upkeeps, and at your draw "
				+ "step it deals that much damage to BOTH players. Any "
				+ "player may pay {4} during any upkeep to take one back "
				+ "off, which is the only brake there is.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Armageddon Clock"]},
				"doom", 44.0),
			_icon("Grapes — vitality",
				"Cue card: \"Vitality counters: 1\". Living Artifact is an "
				+ "aura on an artifact: whenever YOU are dealt damage it "
				+ "takes that many counters, and at your upkeep you may "
				+ "spend one of them to gain a life back.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Living Artifact"]},
				"vitality", 44.0),
			_icon("A bird — carrion",
				"Cue card: \"Carrion counters: 1\". Osai Vultures takes one "
				+ "at the end of any turn a creature died in, and two of "
				+ "them, removed, pump it +1/+1 until end of turn.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Osai Vultures"]},
				"carrion", 44.0),
			_icon("A tombstone — corpse",
				"Cue card: \"Corpse counters: 1\". Scavenging Ghoul takes "
				+ "one at the end of every turn for each creature that "
				+ "died in it, and spends one to regenerate itself.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Scavenging Ghoul"]},
				"corpse", 44.0),
			_icon("The same tombstone — husk",
				"Cue card: \"Husk counters: 1\". Necropolis of Azar takes "
				+ "one whenever a non-black creature reaches a graveyard, "
				+ "and {5} plus one of them makes a Spawn of Azar. Corpse "
				+ "and husk counters share a picture; the cue card tells "
				+ "you which counter you are reading.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Necropolis of Azar"]},
				"husk", 44.0),
			_icon("A whirlwind — wind",
				"Cue card: \"Wind counters: 1\". Cyclone takes one at each "
				+ "of your upkeeps and then charges you {G} for every "
				+ "counter on it or it is sacrificed. Pay, and it deals "
				+ "that much damage to every creature and every player, "
				+ "yours and you included.",
				{"src": SRC_COUNTER,
					"row": CounterMarks.TILE_BY_CARD["Cyclone"]},
				"wind", 44.0),
		]},
		_heading("Two families of five"),
		_text("Two cycles of five cards share one counter between them, and "
			+ "the strip gives every member its own stone in its own "
			+ "color. The order below is the strip's: black, blue, green, "
			+ "red, white."),
		{"kind": ICONS, "entries": [
			_icon_family("Lightning bolts — charge",
				"Cue card: \"Charge counters: 1\". One bolt for each of "
				+ "the five batteries — Black Mana Battery, Blue Mana "
				+ "Battery, Green Mana Battery, Red Mana Battery, White "
				+ "Mana Battery — in that battery's own color. {2} and a "
				+ "tap stores a counter; tapping the "
				+ "battery and taking any number of them off pours that "
				+ "much mana of its own color into your pool at once, "
				+ "which is how a four-mana artifact pays for a spell it "
				+ "could never have paid for in one turn.",
				batteries, "charge", 44.0),
			_icon_family("Ankhs — life",
				"Cue card: \"Life counters: 1\". The five lucky charms — "
				+ "Throne of Bone, Crystal Rod, Wooden Sphere, Iron Star "
				+ "and Ivory Cup — one ankh each, in the color of the "
				+ "spells that charm watches for. These cards grant life "
				+ "immediately when their paid ability resolves; they do "
				+ "not store life counters, so these five icons do not "
				+ "appear on them during a duel.",
				charms, "life", 44.0),
		]},
		_heading("When a counter has no stone"),
		_text("Pupa, glyph, sleep, mire, hatchling and +0/+1 counters use "
			+ "a plain dark chip with their count inside it. Read the cue "
			+ "card for the counter's name and effect."),
		_text("The same dark chip stands in for every stone if you are "
			+ "playing without the 1997 graphics. The count is always "
			+ "there either way; it is only the picture that needs the "
			+ "original files."),
		_heading("One thing that is not a counter"),
		_text("While you are dividing combat damage, every creature you "
			+ "have put points on shows an ICE-BLUE dagger with a running "
			+ "number beside it. That is not a counter and it is not "
			+ "damage yet. It stays visible across assignment groups and "
			+ "clears when the entire damage wave is dealt. The Combat "
			+ "page says more about it."),
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
		_text("Use a pre-combat Stop if you want to tap or remove a creature "
			+ "before it can attack."),
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
			+ "you are attacking, GOLD when your opponent is. Each icon "
			+ "below explains what happens at that point in combat."),
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
		_icon("Unlimited — II", "The base set the game's own cards come "
			+ "from: the printed card has no symbol, so this numeral is "
			+ "this game's own mark for it.",
			{"src": SRC_SET, "code": "2ed"}, "2ED"),
		_icon("Fourth Edition — IV", "An all-reprint base set. Blank on the "
			+ "printed card as well; the IV is this game's.",
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
			+ "end of its type line. The five expansions wear their printed "
			+ "symbol; Unlimited and Fourth Edition never had one printed, "
			+ "so they wear the Roman numerals this game drew for them; the "
			+ "promotional cards are lettered PR."),
		{"kind": ICONS, "entries": sets},
	]}


# --------------------------------------------------- the deck builder --

## The Deck Builder's own page: the surfaces, the bar under the deck, the
## box at the end of the filter strip, and the keys. The 1997 sentences
## are Duel.hlp's; everything the original did not have is marked [QoL]
## here as it is on the screen, so the two never disagree about which is
## which. The command names are the screen's own constants — a test holds
## this page to [constant DeckBuilderScreen.COMMANDS] and its two
## companions, and to [constant DeckBuilderScreen.SHORTCUTS].
static func _page_builder() -> Dictionary:
	return {"title": "The Deck Builder", "blocks": [
		_quote("Along the bottom of the Deck Builder screen is the "
			+ "Inventory area. Here, every card you can put into a deck is "
			+ "available…", "Duel.hlp, topic \"All Cards Inventory\""),
		_text("What the Inventory shows at any moment is what the filter "
			+ "strip above it lets through — the three icon pages after "
			+ "this one explain every medallion on that strip."),
		_quote("To move a card from the inventory into your deck, simply "
			+ "double-click on it or drag it there with the mouse, then "
			+ "release.", "Duel.hlp, topic \"All Cards Inventory\""),
		_text("A single click does the same, in both directions; a "
			+ "right-click on a card moves the whole stack of copies at "
			+ "once; Shift-click sends one copy to the other pile — from "
			+ "the Inventory or the deck to the sideboard, from the "
			+ "sideboard to the deck. The Showcase on the left enlarges "
			+ "whatever the pointer rests on, exactly as it does at the "
			+ "dueling table."),
		_heading("The bar under the deck"),
		_text("STATS opens the statistics window — six pages: Deck, "
			+ "Draws, Mana, Speed, Matchups and Hand. MANA is the mana "
			+ "base audited: what each color asks for in pips against "
			+ "the sources that answer them, how many sources a 90% cast "
			+ "on curve actually needs and whether the deck has them, "
			+ "the land count the curve wants, and the cards still stuck "
			+ "on color. HAND is a sample opening hand dealt from the "
			+ "deck, with the duel's own mulligan and a card a turn — "
			+ "and the window carries the deck's card count on its "
			+ "face. RARITY letters every card on "
			+ "the deck surface C, U, R or L for common, uncommon, rare or "
			+ "legendary; COST lays every card's mana cost on its "
			+ "face. Both are switches: they stay down while their marks "
			+ "are up, and they remember."),
		_text("DECK opens the menu, also available by right-clicking "
			+ "over the deck: AutoDeck at the top, in gold, then New deck, Load deck, Save "
			+ "deck, Consolidate duplicate cards, Clear deck, Sort deck, "
			+ "Stats, Music, Sound Effects, Exit deck builder, Extra "
			+ "Cards, Move by color out of deck, Undo, Big cards, Filters, Add basic land, Add proxy card, "
			+ "Copy deck to, Deck notes, Sideboard, Import deck and Export "
			+ "deck, plus Booster Draft."),
		_text("AutoDeck builds a deck for you from a card pool: "
			+ "the cards of the sets you tick, the cards dealt to you by "
			+ "the Sealed Deck window, or a list of cards from a file or "
			+ "a paste — decklist lines, `4 Lightning Bolt` a line, main "
			+ "and sideboard both counted. Say which colors you like, or "
			+ "none and it picks the strongest in the pool; how many "
			+ "colors at most, up to five; a gold deck, which prefers "
			+ "multicolored cards; 40 or 60 cards; more creatures or more "
			+ "spells; fast, medium or slow; the rarity — anything, "
			+ "common-pauper, no rares, uncommon up or only rares and "
			+ "legends; classic lands, the five basics alone, or "
			+ "non-classic, which lays the pool's dual lands, City of Brass "
			+ "and the lands with abilities first; whether the "
			+ "tournament rules hold; whether to use the Power Nine — off "
			+ "unless you switch it on, and then Black Lotus and the five "
			+ "Moxen go into every deck and Ancestral Recall, Time Walk "
			+ "and Timetwister into a blue deck, when the pool holds them; "
			+ "whether to build around the "
			+ "cards already on the surface; and a seed — the builder is "
			+ "seeded, the deck notes give the roll back, and the same "
			+ "pool, wishes and seed build the same deck again, so leave "
			+ "it blank for a fresh deck every time or type a number to "
			+ "share a build. Build me a deck puts the deck "
			+ "on the surface — Undo brings the old one back — with its "
			+ "reasoning in Deck notes, and puts the pool it built from "
			+ "under the pool medallion beside the dice, so the Inventory "
			+ "shows what is left of it to swap in by hand. Basic lands "
			+ "are always free."),
		_text("Booster Draft opens a timed, sealed-style challenge. Choose "
			+ "eligible sets and cards, pack counts, extra lands, random extras, "
			+ "a time limit and a save folder, then Launch draft. It is also in "
			+ "Options. The top-right countdown starts after the opening animation. "
			+ "Done or time up saves the deck and dealt pool, even if your deck "
			+ "is unfinished. Menus do not pause the timer; only dealt cards can "
			+ "be added. On web, use the results screen's download buttons for "
			+ "external copies. Verify saved deck compares main deck and sideboard "
			+ "with a saved pool. For fair play, the organiser should keep the original "
			+ "pool before building; local files can be edited."),
		_text("New draft decks also save a seed, pack counts and a complete replay "
			+ "recipe as comments. In Verify saved deck, choose the deck and Reconstruct "
			+ "deck to recreate every pack. A judge can paste the fingerprint retained "
			+ "before building. Without that independent reference, reconstruction "
			+ "checks consistency, not whether the player changed the deal."),
		_text("Big cards switches the Showcase to the dueling "
			+ "table's full card size and widens the left column. Its "
			+ "checkmark is remembered for the next startup; untick it to "
			+ "restore the classic layout. Big cards is on by default, "
			+ "but an explicitly saved classic choice is kept. The "
			+ "Inventory keeps its size. If the window is short, scroll "
			+ "the information below the card to read it all. This is "
			+ "separate from the Text switch that expands a card's rules box."),
		_text("The Card variant stone medallion just below the large preview's lower-right corner "
			+ "chooses artwork from your enabled sets. "
			+ "Select a printing, preview it and press Use variant. Automatic follows the set filter. "
			+ "Your saved deck remembers one printing for every copy of that card name, including the sideboard. "
			+ "Rules, copy limits and draft pools stay the same. Missing artwork falls back to the normal face. "
			+ "Portal includes four illustrations for each basic land. Legacy .dck exports do not retain artwork choices."),
		_text("LOAD is a door to the Load Deck dialog from the bar: "
			+ "your own decks head the list, a finder above it keeps the "
			+ "rows whose title or file name contains what you type, "
			+ "Enter loads the first one left, and every row wears the "
			+ "deck's colors as mana symbols. DECK1, DECK2 and DECK3 "
			+ "are three decks in hand at once; the starred one is "
			+ "the deck on the surface. DONE leaves."),
		_heading("The dice at the left of the bar"),
		_quote("Sealed Deck: Compete in the most popular form of Magic "
			+ "Tournament.", "Uistrings.txt, @SHELLSCREEN_DUEL"),
		_text("The dice medallion opens the Sealed Deck Tournament Simulation "
			+ "window: choose how many booster packs (15 cards — one rare "
			+ "or legend, three uncommons, a land, ten commons), starter "
			+ "packs (the tournament pack of 60 — three rares, nine "
			+ "uncommons, twenty-six commons, twenty-two lands), free "
			+ "lands of each type and random cards you are dealt, then "
			+ "press the dice. Every press deals afresh; the packs are "
			+ "listed on the left and the selected pack's cards on the "
			+ "right, lettered L, R, U or C. DONE puts the deal in force: "
			+ "the medallion stays pressed, the Inventory offers only the "
			+ "cards you were dealt, as many copies as you hold, and a "
			+ "card leaves the Inventory when its last copy is in the "
			+ "deck or the sideboard. Make yourself a deck of at least "
			+ "40 cards from it. Pressing the medallion again brings the "
			+ "whole library back."),
		_heading("The box at the end of the filter strip"),
		_quote("At the bottom of the Inventory area is a scroll bar you "
			+ "can use to move through the inventory… or you can type in "
			+ "the first few letters of the name of any card you want to "
			+ "see.", "Duel.hlp, topic \"All Cards Inventory\""),
		_text("The box reading 'type a name' is that field. It matches "
			+ "the start of a name first, then anywhere in it, so 'bolt' "
			+ "still finds Lightning Bolt. The box IS the filter: empty "
			+ "shows everything, text narrows the Inventory as you type, "
			+ "and there is no button to switch it on or off. To clear it, "
			+ "press the small cross at its right edge, or Escape. Enter adds the "
			+ "first card shown to your deck — press it four times for "
			+ "four Lightning Bolts."),
		_text("A right-click on the box, or on any medallion that has no "
			+ "menu of its own, opens the strip's mini-menu: SELECT ALL "
			+ "puts every filter back to where the builder opened, CLEAR "
			+ "ALL puts every color and type medallion up so you can pick "
			+ "a few, and 'Search card text too' makes the box search "
			+ "a card's rules text as well as its name — 'gain life' finds "
			+ "the cards that do."),
		_text("SORT lists the Inventory by Name, Casting cost, Card Type, "
			+ "Color or Set. TEXT is the Showcase's Expand toggle — 1997 "
			+ "keeps a card's text box at its printed size, full grows it "
			+ "to fit."),
		_heading("The keys"),
		_text("Left and Right always walk the yellow selection ring along "
			+ "the bottom Inventory, even after clicking elsewhere in the "
			+ "builder; the row scrolls to keep the selected card in view. "
			+ "Enter adds that card to the deck, or the first card shown if "
			+ "none is selected. Backspace removes one main-deck copy of the "
			+ "selected Inventory card if present; it does not remove from "
			+ "the sideboard. Shift+Enter keeps its transfer action on the "
			+ "focused card surface. Up, Down, PageUp, PageDown, Home and End "
			+ "navigate the focused surface. Text fields keep Enter submission "
			+ "and Backspace editing; open menus and dialogs keep their keys. "
			+ "These shortcuts work in both classic and Big cards layouts."),
		_text("Ctrl+S saves the deck, Ctrl+O loads one, Ctrl+N starts a "
			+ "new one, Ctrl+Z undoes the last change, Ctrl+L adds a basic "
			+ "land, Ctrl+E exports the deck, and Ctrl+F puts the cursor in "
			+ "the type-ahead box with its text selected."),
		_text("Q opens the deck builder's menu — return to the builder, "
			+ "save the current deck, open an existing one, return to the "
			+ "main menu or exit the game, with the music and sound "
			+ "switches under a rule. Escape closes whatever is in the "
			+ "way, in order: that menu, then an open dialog, then a "
			+ "type-ahead holding the keyboard or its text; with nothing "
			+ "in the way it opens the menu."),
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
		_heading("Set-symbol colors on cards"),
		{"kind": ICONS, "entries": [
			_icon("White — Common", "The displayed printing is common.",
				{"src": SRC_SET, "code": "4ed", "rarity": "common"}, "C"),
			_icon("Silver — Uncommon", "The displayed printing is uncommon.",
				{"src": SRC_SET, "code": "4ed", "rarity": "uncommon"}, "U"),
			_icon("Gold — Rare", "The displayed printing is rare.",
				{"src": SRC_SET, "code": "4ed", "rarity": "rare"}, "R"),
			_icon("Purple — Legendary or mythic", "Legendary cards use purple regardless of printed rarity; mythic cards also use purple.",
				{"src": SRC_SET, "code": "4ed", "rarity": "mythic"}, "L/M"),
		]},
		_text("Legendary is a supertype, not a rarity. Reprints use the rarity "
			+ "of the displayed set; set-filter medallions keep their usual colors."),
		{"kind": ICONS, "entries": set_entries},
		_text("Unlimited and the promotional cards use the labels 2nd and PR."),
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
			+ "exclusive options — Land only (the default), Land and Mana, "
			+ "or Mana only: the last two reach every mana source, "
			+ "Llanowar Elves and Sol Ring included, not only lands.",
		Mtg.CardType.ARTIFACT: "A chalice. Up, it hides every artifact — "
			+ "artifact creatures and artifact lands too; keep it down with "
			+ "Creatures to see the artifact creatures. Right-click to tick "
			+ "All Creatures and All Non-Creatures, which are independent "
			+ "of each other.",
		Mtg.CardType.CREATURE: "A bat. Anything with a power and a "
			+ "toughness. Right-click for its page of the Filters window: "
			+ "Non-artifact creatures, Artifact creatures, and a list "
			+ "that narrows them to the selected creature types.",
		Mtg.CardType.ENCHANTMENT: "A crescent moon with NO gold ring — the "
			+ "ringed crescent two places along is The Dark. Lasting magic, "
			+ "local or global. Right-click for its page of the Filters "
			+ "window: Enchantments, World, and the Enchant kinds — Land, "
			+ "Creature, Artifact, Enchant.",
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
		_icon("The Filters window — a funnel",
			"Opens five filter pages: Creatures, Enchantments, Abilities, "
			+ "Rarity and Artists. The funnel is lit while any page narrows "
			+ "the Inventory.",
			{"src": SRC_FILTER, "row": FilterBar.FUNNEL_CELL[0],
				"col": FilterBar.FUNNEL_CELL[1]}, "F"),
		_icon("Sealed Deck — a pair of dice",
			"Not a filter and not on the strip: it sits at the left of "
			+ "the command bar above, beside STATS. Up, the whole library "
			+ "is in the Inventory; press it to open the Sealed Deck "
			+ "Tournament Simulation window and be dealt packs. Down, the "
			+ "Inventory is only what was dealt, and pressing it again "
			+ "brings the whole library back.",
			{"src": SRC_FILTER, "row": FilterBar.DICE_CELL[0],
				"col": FilterBar.DICE_CELL[1]}, "D"),
		_icon("Card pool — three cards",
			"Beside the dice on the command bar: the card pool the AI "
			+ "deck builder last built from. Down, the Inventory shows "
			+ "that pool less what the deck took, so the deck can be "
			+ "modified from what it was built from; press it to bring "
			+ "the whole library back, and again to have the pool back. "
			+ "With no pool built yet, pressing it opens the AI deck "
			+ "builder.",
			{"src": SRC_FILTER, "row": FilterBar.POOL_CELL[0],
				"col": FilterBar.POOL_CELL[1]}, "P"),
	]
	var pages: Array = [
		_icon("Abilities — an eye",
			"Cue card: \"" + DeckFilter.filtered_by_cue_card("ability", true)
			+ "\". Enable Filter turns the page on, and so does unticking "
			+ "an ability. Native keeps cards that simply have an "
			+ "ability, Gives keeps cards that can bestow one; then the "
			+ "thirteen, by their 1997 names with today's in brackets — "
			+ "Ward is protection, Walk is landwalk, Web is reach, Stoning "
			+ "is deathtouch, Free Action is vigilance, Quick draw is "
			+ "haste.",
			{"src": SRC_FILTER, "row": FilterBar.ABILITY_CELL[0],
				"col": FilterBar.ABILITY_CELL[1]}, "Ab"),
		_icon("Rarity — a gem",
			"Cue card: \"" + DeckFilter.filtered_by_cue_card("rarity", true)
			+ "\". The 1997 Rarity medallion. Common, Uncommon and Rare "
			+ "are the printed tiers; Restricted and Banned are the era's "
			+ "tournament lists, so a card can be Rare and Restricted at "
			+ "once — Black Lotus is.",
			{"src": SRC_FILTER, "row": FilterBar.RARITY_CELL[0],
				"col": FilterBar.RARITY_CELL[1]}, "Ra"),
		_icon("Artists — a palette",
			"Cue card: \"" + DeckFilter.filtered_by_cue_card("artist", true)
			+ "\". The 1997 Artist medallion. Every painter in the card "
			+ "pool, listed from the cards themselves; the finder above "
			+ "the list narrows it, and Select All and Clear All act on "
			+ "the names in view.",
			{"src": SRC_FILTER, "row": FilterBar.ARTIST_CELL[0],
				"col": FilterBar.ARTIST_CELL[1]}, "Ar"),
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
		_heading("The Filters window"),
		_text("Five pages behind the funnel — Creatures, Enchantments, "
			+ "Abilities, Rarity, Artists — each tab wearing the medallion "
			+ "the original gave that filter. A page's ticks change the "
			+ "Inventory as you make them; OK keeps them, Cancel puts the "
			+ "page back as it was. On the long pages a finder narrows the "
			+ "list, and Select All and Clear All act on the rows in view, "
			+ "so 'all the Elves and Elementals' is a finder reading 'el' "
			+ "and one click."),
		_text("Abilities, Rarity and Artists each have an Enable Filter "
			+ "switch at the head of the page. Unticking anything in the list "
			+ "presses that switch for you, so 'only the first strikers' "
			+ "is Clear All and one tick; Select All never presses it, "
			+ "because a list that excludes nothing is not a filter. The "
			+ "well below the Showcase says so when it happens."),
		_quote("Initially, all the artists are selected. You can use the "
			+ "Clear All button to de-select everyone and start from "
			+ "scratch. If you change your mind, you can use Select All to "
			+ "return the list to its original, fully selected state. To "
			+ "switch an artist's name from selected to de-selected or "
			+ "vice versa, click on it.",
			"Duel.hlp, topic \"Other Filters\""),
		_text("On the Creatures page, Non-artifact creatures and Artifact "
			+ "creatures choose the two groups. Enable Filter narrows the "
			+ "Inventory to selected creature types. Clear All, then tick "
			+ "Elf to see only Elves immediately. The type list switches "
			+ "on when you narrow it; no OK click is needed. The Artifact "
			+ "medallion must also be on to include artifact creatures."),
		{"kind": ICONS, "entries": pages},
		_quote("Note that the first two filters modify the effects of the "
			+ "others. Native means that the ability is an integral part "
			+ "of the card's makeup; it simply has the ability… Gives "
			+ "refers to those cards which can bestow an ability as an "
			+ "effect, regardless of whether it can be bestowed on the "
			+ "card itself, on another card, or both.",
			"Duel.hlp, topic \"Other Filters\""),
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
		SRC_COUNTER:
			# One oval off `Cardcounters.pic`, cut and masked by the same
			# accessor the small card's counter row draws with.
			return CounterMarks.tile(int(spec.get("row", -1)))
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
			return GameSkin.set_icon(String(spec.get("code", "")),
				String(spec.get("rarity", "")), bool(spec.get("legendary", false)))
		SRC_CURSOR:
			# Target.pic is a strip of square frames; the duel screen shows
			# the first one as the cursor, and so does this.
			var sheet := GameSkin.texture("target_cursor")
			if sheet == null:
				return null
			var side := sheet.get_height()
			return GameSkin.region("target_cursor", Rect2i(0, 0, side, side))
	return null


## Every icon spec ONE ENTRY draws: one for an ordinary entry, several
## for a family entry ([method _icon_family]). The screen and the tests
## both walk this rather than reaching for `icon` themselves, so a family
## row is never half-drawn or half-checked.
static func icon_specs(entry: Dictionary) -> Array:
	if entry.has("icons"):
		return entry["icons"]
	return [entry.get("icon", {})]


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
			for example in block.get("examples", []):
				parts.append(" ".join(example))
			for entry in block.get("entries", []):
				parts.append(String(entry.get("name", "")))
				parts.append(String(entry.get("text", "")))
	return "\n".join(parts)


# --------------------------------------------------------- the builders --

static func _heading(text: String) -> Dictionary:
	return {"kind": HEADING, "text": text}


static func _text(text: String) -> Dictionary:
	return {"kind": TEXT, "text": text}


static func _cards(examples: Array) -> Dictionary:
	return {"kind": CARDS, "examples": examples}


static func _quote(text: String, cite: String) -> Dictionary:
	return {"kind": QUOTE, "text": text, "cite": cite}


## One icon entry. [param alt] is what stands in for the picture when the
## 1997 skin is not imported, so the reference still reads without it.
static func _icon(name: String, text: String, icon: Dictionary, alt: String,
		size := 34.0) -> Dictionary:
	return {"name": name, "text": text, "icon": icon, "alt": alt, "size": size}


## A FAMILY of icons on ONE entry — a set that differs only in color,
## shown as a strip so that five near-identical rows become one row.
##
## A family entry LIVES IN A BLOCK OF ITS OWN, and the test says so: the
## screen sizes an icon row's picture column to the widest picture in it,
## so a block holding both one-icon and five-icon entries would step its
## names in and out. [param size] is each icon's width, as for
## [method _icon].
static func _icon_family(name: String, text: String, icons: Array, alt: String,
		size := 34.0) -> Dictionary:
	return {"name": name, "text": text, "icons": icons, "alt": alt, "size": size}


## An ability badge, addressed by the KEYWORD the mini card draws it for —
## so the entry cannot drift from [constant MiniCard.BADGE_SLOT].
static func _badge_icon(keyword: int, name: String, text: String) -> Dictionary:
	return _icon(name, text,
		{"src": SRC_BADGE, "slot": MiniCard.BADGE_SLOT[keyword]},
		name.substr(0, 1), 32.0)

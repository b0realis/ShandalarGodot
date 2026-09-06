class_name DeckStore
extends RefCounted
## `&Load deck` / `&Save deck` — where the Deck Builder's decks live and
## the 1997 words it uses while moving them — plus the two [QoL] doors out
## of and into that world, `Export deck` and `Import deck`.
##
## Two directories, always both listed:
##   res://decks/   the decks the project ships (read-only in an export) —
##                  the five starter decks at the top, and since
##                  2026-09-02 the ported 1997 MicroProse decks and the
##                  tournament / community / extended community decks in
##                  one subfolder per provenance group (`docs/decks-1997.md`)
##   user://decks/  everything the player builds
## `game/setup_screen.gd` scans the same pair, which is what makes
## "a deck you save is a deck you can duel with" true rather than aspirational.
##
## FILE FORMAT. The original wrote `.dck` and the manual is firm about it
## — *"the file must be a legal DOS file name (only eight characters
## before the period, please) and must have a .dck extension to be
## recognized by Magic: The Gathering as a valid deck file."* We write the
## project's own `.deck` text instead: it round-trips losslessly through
## [DeckList], it is readable in a text editor, and it is what the rest of
## the project already reads. `tools/deck_convert.gd` converts either way
## for anyone who wants the 1997 file. The eight-character DOS limit is
## not reimposed.

const SHIPPED_DIR := "res://decks"
const USER_DIR := "user://decks"
const EXTENSION := ".deck"

## Every extension `DeckList` can read.
const READABLE := [".deck", ".dec", ".dck"]

# The 1997 messages, verbatim but with `.dck` replaced by the actual file
# name so they stay true of what we write. All five are in the GENUINE
# 1997 table, `s30/assets/text/Menus.txt` — `shandalar-src/Program/
# Menus.txt` is the Manalink-updated copy and must not be quoted.
const SAVED := "%s has been saved."                            # @SAVED, :269
const SAVE_ERROR := "There was an error opening %s. The deck has not been saved."
const DECK_EXISTS := "%s already exists. Do you wish to over write?"
const LOAD_ERROR := "%s is not a valid deck file."             # @DECKLOADERROR, :297
const SAVE_QUESTION := "Do you wish to save %s?"               # @SAVE, :265


## Every deck file in both directories, shipped first, each sorted by
## name. Paths, not names — the caller loads them with DeckList.
##
## THE SHIPPED FOLDER HAS SUBFOLDERS since 2026-09-02 — one per provenance
## group, `decks/1997/originals/`, `decks/1997/ancients/`, …,
## `decks/tournament/`, `decks/community/`, `decks/extended_community/`
## (`docs/decks-1997.md`) — and this is the one place
## that walks them. The order is deliberate: the top-level files first
## (the five starter decks, so `all_deck_paths()[0]` is still
## `big_green.deck` and every test that leans on that still holds), then
## the subfolders depth-first, each folder sorted, then the player's own.
## [method deck_paths_in] itself stays ONE folder, no descent — it is what
## the tests use to mean "the starter decks", and `user://decks` is never
## walked below its top level because the Deck Builder saves flat.
static func all_deck_paths() -> Array[String]:
	var out: Array[String] = []
	out.append_array(shipped_paths())
	out.append_array(deck_paths_in(USER_DIR))
	return out


## EVERY DECK THE GAME SHIPS — the five starter decks and the ported 1997,
## tournament, community and extended community decks under them, in
## [method all_deck_paths]'s order and without the player's own. The half
## of that list that is READ-ONLY, which is why it is a function: the
## provenance guard below asks it what the game shipped, and asking the
## whole list and then filtering would have made "shipped" mean two
## different things in one file.
static func shipped_paths() -> Array[String]:
	var out: Array[String] = []
	out.append_array(deck_paths_in(SHIPPED_DIR))
	out.append_array(shipped_subfolder_paths())
	return out


## Every deck file below [constant SHIPPED_DIR]'s subfolders — the ported
## 1997, tournament, community and extended community decks — depth-first,
## folders and files each sorted.
## The top-level starter decks are NOT in this list; see
## [method all_deck_paths] for the whole.
static func shipped_subfolder_paths() -> Array[String]:
	var out: Array[String] = []
	for sub in subfolders_of(SHIPPED_DIR):
		_walk(sub, out)
	return out


static func _walk(dir_path: String, out: Array[String]) -> void:
	out.append_array(deck_paths_in(dir_path))
	for sub in subfolders_of(dir_path):
		_walk(sub, out)


## The subfolders of [param dir_path], sorted, as full paths. Hidden
## folders (a leading dot) are skipped, as [CardRegistry] skips them.
static func subfolders_of(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			found.append(dir_path + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


static func deck_paths_in(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			for suffix in READABLE:
				if entry.to_lower().ends_with(suffix):
					found.append(dir_path + "/" + entry)
					break
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


## [QoL] ONE LINE DESCRIBING A DECK FILE, for the `Load Deck` list:
## `Big Green — 40 cards · big_green.deck`. The 1997 list could only show
## the file name, because an eight-character DOS name was all a `.dck`
## carried outside itself; ours carry a title and a card count, and a
## player with a dozen saved decks should not have to LOAD one to find out
## which it is. The file name stays on the line — it is what `@DECKEXISTS`
## and `Delete` talk about.
##
## A file that will not parse still gets a line, naming itself, so the
## list never hides a deck the player can see in the folder.
static func describe(path: String) -> String:
	return describe_list(DeckList.load_file(path, false), path)


## [method describe] for a list already read — the Load Deck dialog reads
## every file once and wants the line AND the colours from the same read.
static func describe_list(list: DeckList, path: String) -> String:
	var file := path.get_file()
	if not list.errors.is_empty():
		return "%s  (unreadable)" % file
	var title := list.deck_name if list.deck_name.strip_edges() != "" \
		else file.get_basename()
	# The sideboard is named when there is one: it is fifteen cards the
	# player is choosing between decks with, and until the third audit
	# pass loading a deck in the builder threw it away.
	var size := "%d cards" % list.cards.size() if list.sideboard.is_empty() \
		else "%d + %d cards" % [list.cards.size(), list.sideboard.size()]
	# [QoL] AND HOW MANY OF THEM ARE PROXIES, when any are. A deck that
	# cannot be duelled with should say so on the line you pick it from,
	# not once you have loaded it and gone looking for the Go! button.
	var proxies := "" if list.proxies.is_empty() \
		else "  (%d proxy)" % list.proxies.size()
	return "%s — %s%s · %s" % [title, size, proxies, file]


## The colours a deck's cards are, as an `Mtg.ManaColor` mask — every
## colour with at least one card in the main deck. [QoL] The Load Deck
## list wears it as pips, so *"the blue-white one"* can be found among
## three hundred titles that do not say.
static func colors_of(list: DeckList) -> int:
	var mask := 0
	for card_name in list.cards:
		# `has_card` first: a proxy is not an error here, only a card
		# with no colour to count.
		if CardRegistry.has_card(card_name):
			mask |= CardRegistry.get_card(card_name).color_mask()
	return mask & ~Mtg.ManaColor.C


## True for a deck the player may overwrite or delete — one of their own.
## The manual warns about the other kind: *"If you load and change one of
## the creature decks used in the full game, you must save your version of
## the deck under a new name."*
static func is_user_deck(path: String) -> bool:
	return path.begins_with(USER_DIR)


# ------------------------------------------- provenance: the shipped decks --
#
# THE OWNER'S PLAYTEST, 2026-09-04: *"Default decks of the game should not
# be overwritable by the deck builder! (To keep provenance of deck builds
# from 1997.)"*
#
# THE 1997 GAME SAYS THE SAME THING, which is why this is fidelity and not
# only safety — the printed manual, p.148:
#
#   *"If you load and change one of the creature decks used in the full
#   game, you must save your version of the deck under a new name."*
#
# TWO THINGS HAD TO BE TRUE and only one of them already was.
#
#   1. A SHIPPED FILE IS NEVER WRITTEN. It never could be: [method save]
#      builds its path with [method path_for], which is [constant
#      USER_DIR] and nothing else, and `res://decks` is inside the `.pck`
#      of an exported build anyway. That guarantee is now PINNED rather
#      than incidental (`tests/ui/test_deck_provenance.gd` hashes all
#      shipped files around every write door).
#   2. A SHIPPED DECK IS NEVER SHADOWED, and this is the half that was
#      missing. Save a deck called `Cleric` and the file is
#      `user://decks/cleric.deck`; the Load list and the battle-setup
#      picker then hold TWO decks called Cleric, and which of them is the
#      1997 original is a question the player has no way to answer. The
#      original's own answer to that is the sentence above, so this is
#      it: a save under a shipped deck's name is REFUSED — and refused
#      out loud, with the manual's reason, offering a name that works
#      ([method suggest_name]). The Deck Builder turns it into a save-as
#      rather than a failure.
#
# THE COMPARISON IS BY [method file_stem], on BOTH the shipped file's own
# name and the TITLE inside it, because those are the two names a deck has
# and either one colliding is a muddle:
#
#   * the FILE name, because that is what [method path_for] would collide
#     with and what `@DECKEXISTS` and `Delete` talk about;
#   * the TITLE, because that is what the Load list and the picker
#     actually SHOW ([method describe]) — 233 of the shipped files have a
#     title that does not slugify to their file name (`wc1996_rade.deck`
#     is *"Råde — Worlds 1996 (Erhnamgeddon)"*), so a file-name-only
#     check would have let a second "Råde — Worlds 1996" onto the list.
#
# Running both sides through [method file_stem] is what makes the check
# case- and punctuation-blind: `Cleric`, `cleric` and `Cleric!` are one
# name here, exactly as they are one file there.
#
# WHAT IS NOT GUARDED, deliberately: [method export_deck]. It writes to
# `user://decks/export/`, which [method deck_paths_in] never descends
# into, so an export can shadow nothing — and exporting the game's own
# `Cleric` as a `.dck` for the original program to open is a use of the
# provenance, not a threat to it.

## THE MANUAL'S OWN SENTENCE, p.148, verbatim — the reason shown to the
## player, in 1997's words rather than ours. [DeckGroups] quotes it too,
## for the other half of the same rule (a shipped deck the player edits
## and saves correctly STOPS being a shipped deck).
const NEW_NAME_RULE := "If you load and change one of the creature decks used in the full game, you must save your version of the deck under a new name."
## The refusal, naming the FILE the save would have taken — the way
## `@DECKEXISTS` and [method delete_deck] name theirs.
const SHIPPED_NAME := "%s is one of the decks the game ships — save your version under a new name."
## The whole reason, for the dialog that offers the new name. Plainly, and
## in this order: what happened, why 1997 says so, and what to do now.
const SHIPPED_REASON := "%s\n\n\"%s\"\n— the 1997 manual, p.148\n\nName your version and it saves as your own. The game's copy stays exactly as it shipped."

## Every name `res://decks` has taken, as [method file_stem] keys: one per
## shipped FILE and one per shipped TITLE. A set, so the lookup is O(1).
##
## CACHED, and safe to cache because `res://decks` cannot change while the
## game runs — it is read-only in an exported build and nothing in this
## project writes there. Strings only, so it is not the kind of static
## cache `CONTRIBUTING.md` forbids (no [CardData], no [CardInstance]).
static var _shipped_stems: Dictionary = {}


static func shipped_stems() -> Dictionary:
	if not _shipped_stems.is_empty():
		return _shipped_stems
	for path in shipped_paths():
		_shipped_stems[file_stem(path.get_file().get_basename())] = true
		var title := title_in(read_text(path))
		if title != "":
			_shipped_stems[file_stem(title)] = true
	return _shipped_stems


## Would saving under [param deck_name] take a name the game shipped —
## either a shipped file's name or a shipped deck's title? See the block
## comment above for why both.
static func is_shipped_name(deck_name: String) -> bool:
	return shipped_stems().has(file_stem(deck_name))


## The one-line refusal for [param deck_name], for the status line.
static func shipped_name_refusal(deck_name: String) -> String:
	return SHIPPED_NAME % path_for(deck_name).get_file()


## The whole reason, for the dialog that asks for a new name.
static func shipped_reason(deck_name: String) -> String:
	return SHIPPED_REASON % [shipped_name_refusal(deck_name), NEW_NAME_RULE]


## A NAME THE PLAYER CAN ACTUALLY SAVE UNDER, offered rather than
## demanded. *"My Cleric"* first, because that is what the manual is
## asking for in as many words — YOUR version of the deck — and it reads
## as a person would write it. `Cleric 2` is the fallback for the
## vanishingly unlikely case that `My Cleric` is itself shipped.
##
## It only has to clear the SHIPPED names: a collision with one of the
## player's OWN decks is `@DECKEXISTS`, which already asks before it
## overwrites and is the player's business.
static func suggest_name(deck_name: String) -> String:
	var base := deck_name.strip_edges()
	if base == "":
		base = DeckModel.DEFAULT_NAME
	var mine := "My %s" % base
	if not is_shipped_name(mine):
		return mine
	var n := 2
	while is_shipped_name("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


## THE TITLE A DECK FILE DECLARES, or "" when it declares none — the
## `name:` header, or `.dec`'s `// NAME :`. The same two line shapes
## [method DeckList.parse] reads, and the LAST one wins there too, but
## read here without parsing the card list: the guard above asks this of
## every shipped file on every save, and folding 317 decks through
## [DeckList] to learn 317 titles would be a card-name lookup per line.
##
## Tolerant of case (`Name:`) where [method DeckList.parse] is not, which
## is the safe direction for a guard: a file this recognises and the
## parser does not is one more name the player cannot shadow.
static func title_in(text: String) -> String:
	var found := ""
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("//"):
			var body := line.trim_prefix("//").strip_edges()
			if body.to_lower().begins_with("name"):
				var colon := body.find(":")
				if colon != -1:
					found = body.substr(colon + 1).strip_edges()
			continue
		if line.to_lower().begins_with("name:"):
			found = line.substr(5).strip_edges()
	return found


## Deck title -> the file it saves to. Spaces and punctuation become
## underscores so the name is portable; the TITLE itself is preserved
## inside the file by the `name:` header, so nothing is lost.
##
## The mapping is many-to-one — "Knights!" and "Knights?" both land on
## `knights.deck` — which is exactly the collision the original's
## eight-character DOS names had, and it is caught the same way: `Save
## deck` checks [method exists] and puts `@DECKEXISTS` up naming the FILE
## before it overwrites anything.
static func path_for(deck_name: String) -> String:
	return "%s/%s%s" % [USER_DIR, file_stem(deck_name), EXTENSION]


static func file_stem(deck_name: String) -> String:
	var out := ""
	for ch in deck_name.strip_edges().to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return out if out != "" else "new_deck"


static func exists(deck_name: String) -> bool:
	return FileAccess.file_exists(path_for(deck_name))


## Write [param deck] to user://decks/. Returns "" on success or the
## refusal to show — `@NAMEYOURDECK` when it has no title, [constant
## SHIPPED_NAME] when the name is one the game shipped (the manual's own
## rule, p.148 — see the provenance block above), `@DECKSAVEERROR` when
## the file will not open.
##
## THE PATH IS ALWAYS [constant USER_DIR]. There is no branch here that
## can write anywhere else, which is what makes "a shipped deck can never
## be written" a property of the code rather than a promise.
static func save(deck: DeckModel) -> String:
	if deck.deck_name.strip_edges() == "":
		return DeckModel.NAME_YOUR_DECK
	# THE LAST DOOR, not the only one. The Deck Builder catches this
	# earlier and turns it into a save-as with the manual's reason
	# ([method DeckBuilderScreen._save_under_a_new_name]); this is the
	# belt under it, so a caller that forgets — a future command, a tool,
	# a test — still cannot put a second `Cleric` in `user://decks`.
	if is_shipped_name(deck.deck_name):
		return shipped_name_refusal(deck.deck_name)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(USER_DIR))
	var path := path_for(deck.deck_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return SAVE_ERROR % path.get_file()
	file.store_string(deck.to_text())
	file.close()
	return ""


## `%s has been saved.` — the line to show after a successful save.
static func saved_message(deck: DeckModel) -> String:
	return SAVED % path_for(deck.deck_name).get_file()


## Load one deck file into a [DeckModel]. Null means the file is not a
## deck file at all, and `@DECKLOADERROR` — *"%s.dck is not a valid deck
## file."* — is the first line of [param out_report].
##
## A file that IS a deck but names cards we have not built yet LOADS. That
## is the audit pass's correction (2026-08-31): the loader was strict, so
## one unimplemented card refused the whole file and the player got a
## builder that would not open their own deck. The duel's own loader is
## still strict, so an unplayable deck cannot reach a duel by this door.
##
## WHAT HAPPENS TO THOSE NAMES CHANGED ON 2026-09-01: they used to be
## DROPPED, with a line saying which — so a deck opened in the builder and
## saved came back one card short, silently, and the player's own deck was
## edited by opening it. They are now kept as PROXIES ([ProxyCard]): the
## count is right, the file round-trips unchanged, the deck can be looked
## at, and [method DeckModel.proxy_problem] is what says it cannot be
## played. (s30 drops them on the save side —
## `domain/collection.go:258-261` — which is the behaviour this replaces.)
static func load_deck(path: String, out_report: Array) -> DeckModel:
	var lenient := DeckList.load_file(path, false)
	if not lenient.errors.is_empty():
		out_report.append(LOAD_ERROR % path.get_file())
		out_report.append_array(lenient.errors)
		return null
	var model := _fold(lenient, out_report)
	var text := read_text(path)
	model.notes = DeckModel.notes_from_text(text)
	# CARRIED, NOT JUDGED. [method DeckGroups.raw_in] returns whatever the
	# file wrote; the builder never offers a way to type one, and
	# [method DeckGroups.of] still derives `User-created` from the PATH —
	# so keeping the line cannot forge a heading, and dropping it (which
	# is what happened before the third audit pass) silently reclassified
	# every shipped deck a player opened and saved.
	model.group = DeckGroups.raw_in(text)
	return model


## ONE LENIENTLY-PARSED [DeckList] FOLDED INTO A [DeckModel], proxies and
## all. Shared by [method load_deck] and by both halves of Import, which
## is what makes an imported proxy and a loaded one the same object.
##
## Every name goes in verbatim — [method DeckModel.add_proxy] for the ones
## the registry does not know, the plain count for the rest. The names it
## had to proxy are REPORTED in [param out_report] rather than hidden: the
## player is about to be told this deck cannot be duelled with, and the
## first thing they will want is the list.
static func _fold(list: DeckList, out_report: Array) -> DeckModel:
	CardRegistry.ensure_loaded()
	var model := DeckModel.new()
	model.deck_name = list.deck_name if list.deck_name != "" \
		else DeckModel.DEFAULT_NAME
	for card_name in list.cards:
		model.counts[card_name] = int(model.counts.get(card_name, 0)) + 1
	for card_name in list.sideboard:
		model.sideboard[card_name] = int(model.sideboard.get(card_name, 0)) + 1
	if not list.proxies.is_empty():
		out_report.append(PROXIED % [list.proxies.size(),
			"" if list.proxies.size() == 1 else "s",
			", ".join(PackedStringArray(list.proxies))])
	return model


# ------------------------------------------------------- [QoL] import --
# `&Load deck` reads the decks this project keeps ([constant SHIPPED_DIR]
# and [constant USER_DIR]). IMPORT reads a deck from ANYWHERE — a file the
# player points at, or a decklist they paste — and is the other end of the
# `Export deck` road that already exists.
#
# It is ours. `grep -a` over `Program/UIStrings.txt`, `Program/Text.res`,
# `Program/prompts*.txt` and the genuine 1997 `s30/assets/text/Menus.txt`
# finds no "import" and no "paste": the original moved decks by copying
# `.dck` files in DOS, which is why `@DECKLOADERROR` and `@DECKEXISTS`
# talk about file names and nothing talks about importing. So the command
# is marked `[QoL]` in the mini-menu like every other addition.
#
# WHAT MAKES IT DIFFERENT FROM `Load deck` is one word: LENIENT. Load
# already tolerates an unknown name; import is the door that name is
# EXPECTED to come through, so it says how many it proxied and the screen
# leads with that.

## The line a lenient fold reports when it had to proxy names. Ours, in
## our own voice, and it names them — see [ProxyCard].
const PROXIED := "%d card%s became a proxy: %s"
## What Import can read. Every format [DeckList] parses, which is every
## format this project writes.
const IMPORT_FILTERS := ["*.deck ; Shandalar deck", "*.dec ; Decklist",
	"*.dck ; MicroProse 1997 deck"]


## IMPORT A DECK FILE FROM ANYWHERE ON DISK. Returns the model, or null
## with `@DECKLOADERROR` in [param out_report] when the file is not a deck
## at all. Routing is by EXTENSION, exactly as [method DeckList.load_file]
## already routes it — `.dck` to the MicroProse parser, everything else to
## the text one.
static func import_file(path: String, out_report: Array) -> DeckModel:
	var lenient := DeckList.load_file(path, false)
	if not lenient.errors.is_empty():
		out_report.append(LOAD_ERROR % path.get_file())
		out_report.append_array(lenient.errors)
		return null
	var model := _fold(lenient, out_report)
	# A pasted-in or foreign file carries no `# note:` / `# group:` of
	# ours unless it came FROM us, and reading them costs one file read.
	var text := read_text(path)
	model.notes = DeckModel.notes_from_text(text)
	model.group = DeckGroups.raw_in(text)
	return model


## IMPORT A DECKLIST THE PLAYER PASTED. Same fold, same proxies, no file —
## which is how a decklist actually travels today (a forum post, a Discord
## message, another program's export box).
##
## The FORMAT IS SNIFFED rather than asked for, because a pasted list has
## no extension to route on: [method looks_like_dck] recognises the 1997
## file by its own line shape. [param fallback_name] names a list whose
## text does not name itself.
static func import_text(text: String, fallback_name: String,
		out_report: Array) -> DeckModel:
	var lenient := DeckList.new()
	if looks_like_dck(text):
		lenient.parse_dck(text, fallback_name, false)
	else:
		lenient.parse(text, fallback_name, false)
	if not lenient.errors.is_empty():
		out_report.append(PASTE_ERROR)
		out_report.append_array(lenient.errors)
		return null
	var model := _fold(lenient, out_report)
	model.notes = DeckModel.notes_from_text(text)
	return model


## `@DECKLOADERROR` has a file name in it and a pasted list has none, so
## this is the same sentence about the same problem, in our own words.
const PASTE_ERROR := "That is not a decklist we can read."


## IS THIS PASTED TEXT THE 1997 `.dck` FORMAT? Its card lines are
## `.<id> TAB <count> TAB <name>` ([method DeckList.parse_dck]) and no
## other format this project reads has a line beginning with a dot, so one
## such line settles it. The `.v<Colour>` sideboard headers count too — a
## `.dck` whose maindeck is empty is still a `.dck`.
##
## Sniffing rather than asking: a player pasting a decklist should not
## have to know which of three formats they are holding, and getting it
## wrong would be a parse error instead of a deck.
static func looks_like_dck(text: String) -> bool:
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with(".v"):
			return true
		if line.begins_with(".") and line.contains("\t"):
			return true
	return false


## THE FILE'S RAW TEXT. [DeckList] is an `engine/` class and stays pure,
## so it neither knows nor needs to know about the two fields that ride as
## `#` comments — `# note:` and `# group:`, both of which [method
## DeckList.parse] simply skips. This is what reads them back, and it is
## ONE read of the file for both: [method load_deck] used to open the file
## a second time just for the notes.
static func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


# --------------------------------------------------------- [QoL] export --
# Save writes `user://decks/<name>.deck`, which is the format this project
# reads. EXPORT writes the same deck somewhere a DIFFERENT program can
# read it, and there are exactly two of those worth having (the reasoning
# is at DeckModel.to_dec_text): the community decklist every modern tool
# imports, and the 1997 file the original game itself opens. Both land in
# `user://decks/export/` so an export never shadows a save.

const EXPORT_DIR := "user://decks/export"
## Menu label -> extension. The order is the order the mini-menu lists them.
const EXPORT_FORMATS: Array = [
	["Decklist (.dec) — for other Magic programs", ".dec"],
	["MicroProse 1997 (.dck) — for the original game", ".dck"],
]
const ID_TABLE_PATH := "res://cards/data/dck_ids.txt"
const EXPORTED := "%s has been exported."


## Write [param deck] out in [param extension] (".dec" or ".dck").
## Returns "" on success or the refusal to show, and appends the path
## written to [param out_path] so the caller can name it.
static func export_deck(deck: DeckModel, extension: String,
		out_path: Array) -> String:
	if deck.total() == 0:
		return "There is nothing to export."
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EXPORT_DIR))
	var path := "%s/%s%s" % [EXPORT_DIR, file_stem(deck.deck_name), extension]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return SAVE_ERROR % path.get_file()
	file.store_string(deck.to_dck_text(dck_ids()) if extension == ".dck"
		else deck.to_dec_text())
	file.close()
	out_path.append(path)
	return ""


## card name -> the original's numeric id, from the 371-entry table
## `tools/deck_convert.gd` harvested from a real game copy. Cached: the
## table is only read when a `.dck` is actually written.
static var _ids: Dictionary = {}

static func dck_ids() -> Dictionary:
	if not _ids.is_empty():
		return _ids
	var file := FileAccess.open(ID_TABLE_PATH, FileAccess.READ)
	if file == null:
		return _ids
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		# `name|id`, the shape tools/deck_convert.gd harvested it in.
		var bar := line.rfind("|")
		if bar == -1:
			continue
		var card_name := line.substr(0, bar).strip_edges()
		var id := line.substr(bar + 1).strip_edges()
		if id.is_valid_int():
			_ids[card_name] = id.to_int()
	file.close()
	return _ids


## Delete one of the player's own decks. Shipped decks refuse.
static func delete_deck(path: String) -> String:
	if not is_user_deck(path):
		# ONE VOICE with the save guard above — Delete and Save refuse a
		# shipped deck for the same reason and say it in the same words.
		return SHIPPED_NAME % path.get_file()
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		return SAVE_ERROR % path.get_file()
	return ""

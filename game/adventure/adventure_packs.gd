class_name AdventurePacks
extends RefCounted
## Campaign-local card modules, independent of their optional adventure providers.
## CardPacks owns installation and card rules; this layer owns campaign eligibility.
## An adventure is linked by its descriptor's pack ID, never by a special-case shop.
## THE CARDS A CAMPAIGN'S PACKS BRING (0.60.14, the owner's pack rulings of
## 2026-11-03), any of Packs 2–10, an old save's too: each pack its own cards
## ([method card_stock]; Fifth Edition its 147 reprints), at their original
## printing's rarity ([method printed_rarity], [method facts]); a card made
## for ante on no shelf ([method pools]); the strong ones special
## ([constant CardValue.STRONG_PACK_CARDS]); in a random draw their share
## ([PackShare]), in a list every card ([method add_stock]).

static var _stock := {}
static var _revision := -1
## THE TRUSTED CATALOGUES' WORD ON EACH PACK CARD ([method _read_catalogues];
## strings only, read once): the pack that introduced a card, its rarity
## there, the packs that carry it as a shared reprint, and Fifth Edition's
## rarity of its 147 reprints.
static var _owner := {}
static var _printed := {}
static var _carriers := {}
static var _fifth := {}
static var _own := {}
static var _catalogues_read := false

static func forget() -> void:
	_stock.clear()
	_revision = -1

static func selected(player: AdventurePlayer, pack: String) -> bool:
	return player != null and player.packs.any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id", "") == pack)

static func adventures(pack: String) -> Array[String]:
	var out: Array[String] = []
	for id in AdventureExpansions.definitions():
		if AdventureExpansions.definition(id).get("pack", "") == pack: out.append(id)
	return out

## Selecting cards on Embark enables their installed rules once, when setting out.
## Other packs' duel settings are left alone; they do not join this campaign.
## IN ONE REBUILD (0.60.15, the owner's ruling of 2026-11-03: "Embark: no
## frozen window"): every pack of [param ids] that is off is switched on at
## once ([method CardPacks.set_enabled_many]) — one at a time, the card pool
## was rebuilt once a pack, eight times for Packs 2–9: 3.2 s of a frozen
## window before the hourglass. [param aside]: the rebuild compiles on a
## thread and this returns at once; the caller waits for [method
## CardRegistry.poll] behind its hourglass ([method EmbarkScreen.embark]).
## Refused before anything is switched ([method activate_refusal]).
static func activate(ids: Array[String], aside := false) -> String:
	var refusal := activate_refusal(ids)
	if refusal != "": return refusal
	var off := to_enable(ids)
	if off.is_empty(): return ""
	if not AdventureExpansions.packs().set_enabled_many(off, true, aside):
		return "Could not enable %s. Check Options › Card Packs." % _titles(off)
	return ""

## Why [param ids] cannot be switched on now ([method activate]), "" when
## they can or are on already. Changes nothing.
static func activate_refusal(ids: Array[String]) -> String:
	if ids.is_empty(): return ""
	var service := AdventureExpansions.packs()
	if service == null: return "Card packs are unavailable."
	for id in ids:
		if not service.has_pack(id): return "Install %s in Options › Card Packs before setting out." % title(id)
		if not service.is_enabled(id) and service.change_refusal() != "": return service.change_refusal()
	return ""

## The packs of [param ids] installed but switched off — those [method
## activate] switches on — in their order.
static func to_enable(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var service := AdventureExpansions.packs()
	if service == null: return out
	for id in ids:
		if service.has_pack(id) and not service.is_enabled(id) and not id in out: out.append(id)
	return out

static func _titles(ids: Array[String]) -> String:
	var out: Array[String] = []
	for id in ids: out.append(title(id))
	return ", ".join(out)

## A pack as the Embark lists it, "Pack 2 · Fallen Empires"; one not installed
## by its file, "Pack 2 (Pack-2-Fallen-Empires.zip)"; one this build does not
## know by its number alone.
static func title(id: String) -> String:
	var service := AdventureExpansions.packs()
	var label := "Pack " + id.trim_prefix("pack-")
	if service == null: return label
	var info: Dictionary = service.info(id)
	if info.has("name"): return "%s · %s" % [label, info["name"]]
	return "%s (%s)" % [label, service.file_name_for(id)] if id in service.known_ids() else label

## A SAVED CAMPAIGN'S PACKS, AS IT IS TAKEN UP AGAIN (0.60.13 bug campaign,
## h3-1; the owner, 2026-10-28: "resume with a notice (a missing pack
## refuses and says which)"). Before, a campaign resumed silently without
## its pack: the pack's cards dropped out of every duel with errors, and the
## hero could still stake and lose them. A pack not installed refuses the
## load and is named; one installed but switched off is enabled, as setting
## out does ([method activate]), and named in the notice. `{refusal,
## enabled}`: the refusal "" when the campaign may resume; the packs enabled
## now, by [method title]. Pack 1 is never a campaign's (AdventureSetup).
## Those switched off are switched on in ONE rebuild, on a thread with
## [param aside] (0.60.15, the owner's ruling of 2026-11-03: "Same for
## `resume` on load"; [method activate], [method LoadAdventureScreen.open_save]).
static func resume(player: AdventurePlayer, aside := false) -> Dictionary:
	var enabled: Array[String] = []
	var ids: Array[String] = []
	for row in player.packs:
		var id: String = row["id"] if row is Dictionary and row.get("id") is String else ""
		if id != "" and not id in AdventureSetup.IGNORED_PACKS and not id in ids: ids.append(id)
	var service := AdventureExpansions.packs()
	var missing: Array[String] = []
	for id in ids:
		if service == null or not service.has_pack(id): missing.append(title(id))
	if not missing.is_empty():
		var one := missing.size() == 1
		return {"refusal": "This adventure needs the card %s %s. Add %s in Options › Card Packs, then resume." % [
			"pack" if one else "packs", " and ".join(missing), "it" if one else "them"], "enabled": enabled}
	var off: Array[String] = []
	for id in ids:
		if not service.is_enabled(id): off.append(id)
	if off.is_empty(): return {"refusal": "", "enabled": enabled}
	if service.change_refusal() != "":
		return {"refusal": "This adventure needs %s enabled. %s" % [title(off[0]), service.change_refusal()], "enabled": enabled}
	if not service.set_enabled_many(off, true, aside):
		return {"refusal": "Could not enable %s. Check Options › Card Packs." % _titles(off), "enabled": enabled}
	for id in off: enabled.append(title(id))
	AdventureExpansions.sync_choices(player)
	return {"refusal": "", "enabled": enabled}

## The pack [param card_name] comes in, by the packs this build knows,
## installed or not; "" for none (a base card, or a name no pack has). For
## [param player]'s campaign, one of ITS packs that brings the card when
## there is one (0.60.14, the owner's pack rulings of 2026-11-03): a shared
## reprint — Pyroblast is Ice Age's, and Fifth Edition carries it — is named
## by the pack the hero chose, not by the first that could provide it.
static func card_pack(card_name: String, player: AdventurePlayer = null) -> String:
	var service := AdventureExpansions.packs()
	if service == null: return ""
	if player != null and not player.packs.is_empty():
		_read_catalogues()
		var providers: Array = [String(_owner.get(card_name, ""))]
		providers.append_array(_carriers.get(card_name, []))
		for id in providers:
			if id != "" and selected(player, id): return id
	var names: Array[String] = [card_name]
	var ids: Array[String] = service.packs_required_by(names)
	return ids[0] if not ids.is_empty() else ""

## Why a card the game does not know now cannot be bought, naming its pack
## (the owner's polish of 2026-11-03, [method CardShop._mark_unavailable]) —
## for [param player], a pack of the campaign's ([method card_pack]).
static func card_refusal(card_name: String, player: AdventurePlayer = null) -> String:
	var pack := card_pack(card_name, player)
	if pack == "": return "Enable this card's pack to buy it."
	var service := AdventureExpansions.packs()
	return "%s this card's pack, %s, to buy it." % ["Enable" if service.has_pack(pack) else "Install", title(pack)]

## The notice of [method resume]'s packs enabled, "" for none.
static func enabled_notice(titles: Array[String]) -> String:
	if titles.is_empty(): return ""
	return "Card %s enabled for this adventure: %s." % ["pack" if titles.size() == 1 else "packs", ", ".join(titles)]

static func offers_cards(player: AdventurePlayer, pack: String) -> bool:
	if not selected(player, pack): return false
	var service := AdventureExpansions.packs()
	if service == null or not service.is_enabled(pack): return false
	if not player.expanded_adventure: return true
	var lands := adventures(pack)
	# Packs without an adventure are still complete card modules.
	if lands.is_empty(): return true
	for id in lands:
		var field: String = AdventureExpansions.definition(id).get("cards_unlock", "liberated")
		if AdventureRegions.id(player.world) == id or bool(AdventureExpansions.progress(player, id).get(field, false)):
			return true
	return false

## THE PACKS THAT GIVE [param player]'S CAMPAIGN CARDS NOW, in pack order:
## each chosen pack that [method offers_cards] — never Pack 1 nor a pack this
## build does not know, though a hand-edited save names one (0.60.14, the
## study's small fix: `pack-1` stocked Chaos Orb, Shahrazad, Falling Star).
## The pack share counts these ([PackShare]).
static func campaign_packs(player: AdventurePlayer) -> Array[String]:
	var out: Array[String] = []
	if player == null or player.packs.is_empty(): return out
	var service := AdventureExpansions.packs()
	if service == null: return out
	for id in service.known_ids():
		if not id in AdventureSetup.IGNORED_PACKS and offers_cards(player, id): out.append(String(id))
	return out

## EACH CAMPAIGN PACK'S CARDS, one list of `{name, facts}` a pack, in [method
## campaign_packs]' order — what the pack share draws from. [param shelves]:
## a shop's, without the cards made for ante (0.60.14, the owner's pack
## rulings of 2026-11-03: "Ante cards never on shelves" — out of a shop's
## places only; trades, spoils and lairs have them as the base's own ante
## cards, Contract from Below and the rest). Fifth Edition's reprints at its
## rarity unless their own pack is chosen too ([method fifth_printing]).
static func pools(player: AdventurePlayer, shelves := false) -> Array:
	var out: Array = []
	for id in campaign_packs(player):
		var rows := card_stock(id, shelves)
		if id == FifthEditionPack.ID:
			var mine: Array[Dictionary] = []
			for row in rows:
				var card := String(row["name"])
				mine.append(row if fifth_printing(player, card)
					else {"name": card, "facts": CardValue.facts(CardRegistry.get_card(card))})
			rows = mine
		out.append(rows)
	return out

## [param base] and every row of [param packs] ([method pools]) once, by name.
static func joined(base: Array[Dictionary], packs: Array) -> Array[Dictionary]:
	if packs.is_empty(): return base
	var out := base.duplicate()
	var held := {}
	for row in base: held[row["name"]] = true
	for rows in packs:
		for row in rows:
			if held.has(row["name"]): continue
			held[row["name"]] = true
			out.append(row)
	return out

## THE LISTS — trades, a castle's pick, any card of the hero's choice:
## [param base] and every campaign pack's cards once ([method pools]).
static func add_stock(player: AdventurePlayer, base: Array[Dictionary]) -> Array[Dictionary]:
	if player == null or player.packs.is_empty(): return base
	return joined(base, pools(player))

## A PACK'S OWN CARDS (0.60.14, the owner's pack rulings of 2026-11-03:
## "Each pack brings only its own"): the identities pack [param id]
## introduced — its trusted contract's new names, as `scripts()` hosts them
## — that the card pool holds now; a reprint of another pack's card comes
## with that pack. Fifth Edition introduced none: it brings its 147 Fallen
## Empires, Ice Age and Homelands reprints, at Fifth Edition's rarity
## ([method fifth_facts]). [param shelves]: less the cards made for ante
## ([method MtgGame.is_ante_card]). Cache values only, never CardData or
## artwork. Printing variants count once.
## Read on a worker as the world opens when it can be ([method warm]):
## one still at work is waited for here, by the first draw that needs it.
static func card_stock(id: String, shelves := false) -> Array[Dictionary]:
	if _warm_thread != null: settle_warm()
	_follow_pool()
	var key := id + ("|shelves" if shelves else "")
	if _stock.has(key): return _stock[key]
	_read_catalogues()
	var rows := _rows_of(id, shelves, func(data: CardData) -> Dictionary: return CardValue.facts(data),
		func(card: String) -> Dictionary: return fifth_facts(card))
	_stock[key] = rows
	return rows

## [method card_stock]'s rows, the facts by [param facts_of] (a card's
## [CardData] to its facts) and, for Fifth Edition's, [param fifth_of] (a
## name to its facts at Fifth Edition's rarity): the caches' on the main
## thread, read apart on [method warm]'s worker — the one walk for both.
static func _rows_of(id: String, shelves: bool, facts_of: Callable, fifth_of: Callable) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for card in _own.get(id, []):
		if not CardRegistry.has_card(card): continue
		# A reprint must not bypass a core trader's treasure/withheld-card rules.
		if CardTrade.in_adventure(card): continue
		var data := CardRegistry.get_card(card)
		if shelves and MtgGame.is_ante_card(data): continue
		rows.append({"name": card, "facts": fifth_of.call(card) if id == FifthEditionPack.ID else facts_of.call(data)})
	return rows

## Whether [param card_name] is, in [param player]'s campaign, a card of
## Fifth Edition's selection at its Fifth Edition printing: Pack 7 chosen
## and the card's own pack not (0.60.14, the owner's pack rulings of
## 2026-11-03: "Its 147 reprints join" as Fifth Edition printings, the
## original's rarity when the original pack is also chosen).
static func fifth_printing(player: AdventurePlayer, card_name: String) -> bool:
	if player == null or player.packs.is_empty() or not selected(player, FifthEditionPack.ID): return false
	_read_catalogues()
	return _fifth.has(card_name) and not selected(player, String(_owner.get(card_name, "")))

## [param card_name]'s facts ([method CardValue.facts]) at Fifth Edition's
## rarity: read-only, kept while the card pool stands.
static func fifth_facts(card_name: String) -> Dictionary:
	_follow_pool()
	_read_catalogues()
	var f := CardValue.facts(CardRegistry.get_card(card_name))
	var key := "5ed|" + card_name
	if _stock.has(key): return _stock[key]
	var fifth := _at_fifth_rarity(card_name, f)
	if not is_same(fifth, f): _stock[key] = fifth
	return fifth

## [param f] at Fifth Edition's rarity of [param card_name]: [param f] itself
## when that is its own (or there is none), else a read-only copy.
static func _at_fifth_rarity(card_name: String, f: Dictionary) -> Dictionary:
	var rank := CardValue.rank_of(String(_fifth.get(card_name, "")))
	if rank == 0 or rank == int(f.get("rarity", 1)): return f
	var out := f.duplicate()
	out["rarity"] = rank
	out.make_read_only()
	return out

## [param card_name]'s facts in [param player]'s campaign: [method
## CardValue.facts], a Fifth Edition card at its Fifth Edition rarity there
## ([method fifth_printing]) — the price, the amulets, the spoils' budget
## and the lairs' rarity read it. The card must be in the pool.
static func facts(player: AdventurePlayer, card_name: String) -> Dictionary:
	if fifth_printing(player, card_name): return fifth_facts(card_name)
	return CardValue.facts(CardRegistry.get_card(card_name))

## THE ORIGINAL PRINTING'S RARITY of pack card [param card_name] (0.60.14,
## the owner's pack rulings of 2026-11-03: "Rarity is deterministic", never
## whichever pack is switched on first in Options): its rarity in the
## trusted catalogue of the pack that introduced it, the first of that
## pack's sets to print it (Wood Elves Portal's rare, not Exodus's common;
## Mountain Goat Ice Age's common, not Portal's uncommon). "" for a card no
## numbered pack introduced (a base card, Pack 1's four).
static func printed_rarity(card_name: String) -> String:
	_read_catalogues()
	return String(_printed.get(card_name, ""))

## The pack that introduced [param card_name] ([method printed_rarity]), "".
static func owner_of(card_name: String) -> String:
	_read_catalogues()
	return String(_owner.get(card_name, ""))

# --- 0.60.15: the campaign's pack cards read on a worker as the world opens ---

## THE CAMPAIGN'S PACK CARDS READ AS THE WORLD OPENS, ON A WORKER (0.60.15,
## the owner's ruling of 2026-11-03: "Prewarm pack prices"). The first pack
## draw of a session — a town's shelves, a trade list, a duel's spoils, a
## lair — read the facts of every card of the campaign's packs ([method
## card_stock], [method CardValue.facts]) on the thread that draws: 190–313
## ms with Packs 2–9 on the desk. [method warm] (main thread, as the world
## opens: [method WorldSoundscape.warm_arrival]) hands that reading to a
## [Thread] of its own — not the engine's pool, where the low-priority
## warm-ups run one at a time ([SkinWarmer]) and it could wait behind
## them. The worker walks [method _rows_of], the very walk of [method
## card_stock], with each card's facts read apart from every cache ([method
## CardValue.read_aside], a scorer of its own): the same code on the same
## cards, so the same rows. [method settle_warm] (main thread) takes them
## in — once the worker is done ([method warm_done], asked as the world's
## clock ticks), or at the first draw that comes before it is, which waits
## for the rest ([method card_stock]). The worker writes nothing shared and
## reads only the card pool and tables complete before it starts; a pool
## about to change stops it first and waits ([method stop_warm], from
## [method CardPacks._configure_registry]), as leaving the world does.
## Not headless (the tests, the tools: a test must not race a thread), not
## on the Web, nor without threads ([member warm_forced]): there the first
## draw reads the cards, as before.
static var _warm_thread: Thread = null
static var _warm_job: WarmJob = null
## Tests: 1 warms headless too, 0 never, -1 by the rule (as [member
## SkinWarmer.forced]).
static var warm_forced := -1

## What [method warm]'s worker is given: the packs to read (`[id, shelves]`
## each), the pool's revision and the 1997 table ([method
## CardValue.imported_table]) as they stood, the hero it was started for
## (an instance id), and a stop asked under its lock.
class WarmJob extends RefCounted:
	var lock := Mutex.new()
	var stop := false
	var revision := -1
	var owner := 0
	var table: Dictionary = {}
	var jobs: Array = []

	func stopped() -> bool:
		lock.lock()
		var asked := stop
		lock.unlock()
		return asked

	func ask_stop() -> void:
		lock.lock()
		stop = true
		lock.unlock()

## Start reading [param player]'s campaign packs' cards on a worker (see
## above). Main thread. False when there is nothing to read (no campaign
## pack, every one read already), one is at work, or no worker may run here.
static func warm(player: AdventurePlayer) -> bool:
	if _warm_thread != null or not _warm_runs_here(): return false
	var ids := campaign_packs(player)
	if ids.is_empty(): return false
	_follow_pool()
	_read_catalogues()
	var job := WarmJob.new()
	for id in ids:
		for shelves in [false, true]:
			if not _stock.has(id + ("|shelves" if shelves else "")): job.jobs.append([id, shelves])
	if job.jobs.is_empty(): return false
	job.revision = CardRegistry.revision
	job.table = CardValue.imported_table()
	job.owner = player.get_instance_id()
	var thread := Thread.new()
	if thread.start(func() -> Dictionary: return _read_aside(job)) != OK: return false
	_warm_thread = thread
	_warm_job = job
	return true

## Whether [method warm]'s worker is out (at work or done, not yet taken in).
static func warming() -> bool:
	return _warm_thread != null

## Whether [method warm]'s worker is done, its rows waiting to be taken in
## ([method settle_warm]) — which then waits for nothing.
static func warm_done() -> bool:
	return _warm_thread != null and not _warm_thread.is_alive()

## THE WORKER'S ROWS TAKEN IN (main thread): waited for if still at work,
## then kept as [method card_stock] and [method CardValue.facts] would have
## kept them — unless the pool or the 1997 table moved on meanwhile; what
## the main thread read meanwhile is kept, and the rows point at it.
static func settle_warm() -> void:
	if _warm_thread == null: return
	var out: Variant = _warm_thread.wait_to_finish()
	var job := _warm_job
	_warm_thread = null
	_warm_job = null
	if not (out is Dictionary) or (out as Dictionary).is_empty(): return
	if job.revision != CardRegistry.revision or not is_same(job.table, CardValue.imported_table()): return
	_follow_pool()
	var moved := CardValue.adopt(out["facts"])
	var fifth: Dictionary = out["fifth"]
	var fifth_moved := {}
	for card in fifth:
		var key := "5ed|" + String(card)
		if _stock.has(key): fifth_moved[card] = _stock[key]
		else: _stock[key] = fifth[card]
	var stock: Dictionary = out["stock"]
	for key in stock:
		if _stock.has(key): continue
		var at_fifth := String(key).get_slice("|", 0) == FifthEditionPack.ID
		var rows: Array[Dictionary] = stock[key]
		# The rows point at the facts kept: the worker's, but where the main
		# thread read a card meanwhile (seldom), at those.
		if not moved.is_empty() or (at_fifth and not fifth_moved.is_empty()):
			for row in rows:
				var card := String(row["name"])
				if at_fifth and fifth.has(card):
					row["facts"] = fifth_moved.get(card, row["facts"])
				else:
					row["facts"] = moved.get(card, row["facts"])
		_stock[key] = rows

## [method warm]'s worker stopped and waited for, its rows let go: the card
## pool about to change; the world of [param player] left — a worker
## started for another hero's world (one loaded from this one) goes on.
## Main thread.
static func stop_warm(player: AdventurePlayer = null) -> void:
	if _warm_thread == null: return
	if player != null and _warm_job.owner != player.get_instance_id(): return
	_warm_job.ask_stop()
	_warm_thread.wait_to_finish()
	_warm_thread = null
	_warm_job = null

static func _warm_runs_here() -> bool:
	if warm_forced >= 0: return warm_forced == 1
	return OS.has_feature("threads") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"

## THE WORKER ([method warm]): [param job]'s packs walked as [method
## card_stock] walks them, each card's facts read apart ([method
## CardValue.read_aside]) and Fifth Edition's at its rarity ([method
## _at_fifth_rarity]) — into locals only. `{facts: {name: facts}, fifth:
## {name: facts at 5ED's rarity, where it differs}, stock: {key: rows}}`,
## `{}` when stopped.
static func _read_aside(job: WarmJob) -> Dictionary:
	var scorer := AutoDeck.new()
	var facts := {}
	var fifth := {}
	var facts_of := func(data: CardData) -> Dictionary:
		if not facts.has(data.card_name):
			var f := CardValue.read_aside(data, job.table, scorer)
			f.make_read_only()
			facts[data.card_name] = f
		return facts[data.card_name]
	var fifth_of := func(card: String) -> Dictionary:
		if fifth.has(card): return fifth[card]
		var f: Dictionary = facts_of.call(CardRegistry.get_card(card))
		var at := _at_fifth_rarity(card, f)
		if not is_same(at, f): fifth[card] = at
		return at
	var stock := {}
	for pair in job.jobs:
		if job.stopped(): return {}
		var id := String(pair[0])
		var shelves := bool(pair[1])
		stock[id + ("|shelves" if shelves else "")] = _rows_of(id, shelves, facts_of, fifth_of)
	return {"facts": facts, "fifth": fifth, "stock": stock}

# --- end 0.60.15 ---

## The cards and facts kept ([member _stock]) read again when the card pool
## has moved on (a pack switched on or off).
static func _follow_pool() -> void:
	CardRegistry.ensure_loaded()
	if _revision != CardRegistry.revision:
		_stock.clear()
		_revision = CardRegistry.revision

## The trusted catalogues that ship in the game (`res://packaging/
## card_packs/`, each pack's contract: [method CardPacks.expansions]), read
## once — never a zip's word. Strings only.
static func _read_catalogues() -> void:
	if _catalogues_read: return
	var service := AdventureExpansions.packs()
	if service == null: return
	_catalogues_read = true
	for contract in service.expansions():
		var id := String(contract.ID)
		var words := {}
		for row in contract.records():
			var card := String(row.get("name", ""))
			if not words.has(card): words[card] = String(row.get("rarity", ""))
		var own: Array = contract.names() if id == FallenEmpiresPack.ID else contract.new_names()
		var carried: Dictionary = {}
		if id == PortalPack.ID: carried = PortalPack.SHARED
		elif id in [FifthEditionPack.ID, MirageBlockPack.ID, TempestBlockPack.ID, UrzaBlockPack.ID]: carried = contract.shared()
		for card in own:
			_owner[card] = id
			_printed[card] = words.get(card, "")
		for card in carried:
			if not _carriers.has(card): _carriers[card] = []
			(_carriers[card] as Array).append(id)
			if id == FifthEditionPack.ID: _fifth[card] = words.get(card, "")
		var cards: Array[String] = []
		cards.assign(carried.keys() if id == FifthEditionPack.ID else own)
		_own[id] = cards

## Earlier expedition saves predate the independent checkbox. Preserve only
## adventures evidenced by saved entries/progress/regions, not global settings.
static func migrate(player: AdventurePlayer, version: int) -> void:
	if version >= 7: return
	var lands := {}
	for id in player.expansions: lands[id] = true
	for id in player.regions: lands[id] = true
	lands[AdventureRegions.id(player.world)] = true
	var extra := player.world.expansion
	for id in extra.get("entries", {}): lands[id] = true
	if extra.has("port") and AdventureRegions.mainland(player): lands["refuge"] = true
	lands.erase(AdventureRegions.MAINLAND)
	player.expanded_adventure = not lands.is_empty()
	for id in lands:
		var pack: String = AdventureExpansions.definition(id).get("pack", "")
		if pack == "" or selected(player, pack): continue
		var service := AdventureExpansions.packs()
		var info: Dictionary = service.info(pack) if service != null else {}
		player.packs.append({"id": pack, "version": str(info.get("version", ""))})

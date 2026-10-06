extends RefCounted
## Exodus (_slivers, Pack 9). Slivers: creatures whose abilities every Sliver on the battlefield shares.
## Nothing is claimed yet: every name falls through to the dispatcher's
## fail-closed `_pending` guard until a card wave adds it here.

static func configure(c: CardData) -> bool:
	match c.card_name:
		_:
			return false

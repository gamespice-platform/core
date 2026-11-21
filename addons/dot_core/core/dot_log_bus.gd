class_name GSLogBus
extends RefCounted

## Carries [GSLog]'s per-record signal: a static class cannot declare one and GameSpice Core owns no autoload, so
## [method GSLog.signals] creates this on demand. [code]GSLog.signals().record.connect(fn)[/code]. [GSLog] keeps a reference.

## One log record. See [method GSLog._emit] for the dictionary's shape.
signal record(rec: Dictionary)

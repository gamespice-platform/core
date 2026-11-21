class_name GSRegistryBus
extends RefCounted

## Carries [GSRegistry]'s signals, as [GSLogBus] does for logs: a static class cannot declare one.
## [code]GSRegistry.signals().service_registered.connect(fn)[/code].

signal service_registered(name: StringName, instance: Object)
signal service_unregistered(name: StringName)

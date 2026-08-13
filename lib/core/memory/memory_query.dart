/// MemoryQuery — static keyword matcher for MemoryEntry lists.
///
/// The full implementation lives in memory_store.dart as the MemoryQuery class.
/// This file re-exports it for callers who only need the query functionality.
///
/// This file has zero Flutter imports — pure Dart only.
library memory_query;

export 'memory_store.dart' show MemoryQuery;

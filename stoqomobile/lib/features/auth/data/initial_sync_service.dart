/// InitialSyncService is no longer used — the app is fully offline.
/// Kept as a stub to avoid import errors during the transition.
class InitialSyncService {
  const InitialSyncService();
  Future<void> syncBranch(String branchId, {String? cursor}) async {}
}

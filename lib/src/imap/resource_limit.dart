/// QUOTA resource limit
class ResourceLimit {
  /// Creates a new resource limit
  ResourceLimit(this.name, this.currentUsage, this.usageLimit);

  /// The quota resource name.
  final String name;

  /// Current resource usage in kilobytes.
  final int? currentUsage;

  /// Usage limit of the resource as kilobytes.
  final int? usageLimit;
}

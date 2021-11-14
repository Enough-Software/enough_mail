/// QUOTA resource limit
class ResourceLimit {
  /// Creates a new resource limit
  ResourceLimit(this.name, this.currentUsage, this.usageLimit);

  /// The quota resource name.
  final String name;

  /// Current resource usage in kibibytes.
  final int? currentUsage;

  /// Usage limit of the resource as kibibytes.
  final int? usageLimit;
}

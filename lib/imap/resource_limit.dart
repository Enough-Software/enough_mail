/// QUOTA resource limit
class ResourceLimit {
  /// The quota resource name.
  final String name;

  /// Current resource usage in kibibytes.
  final int currentUsage;

  /// Usage limit of the resource as kibibytes.
  final int usageLimit;

  ResourceLimit(this.name, this.currentUsage, this.usageLimit);
}

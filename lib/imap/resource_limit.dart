/// QUOTA resource limit
class ResourceLimit {
  /// The quota resource name.
  final String name;

  /// Current resource usage in kibibytes.
  final int currentUsage;

  /// Usage limit of the resource as kibibytes.
  final int usageLimit;

  ResourceLimit(this.name, this.currentUsage, this.usageLimit);

  /// Helper method for determining a unlimited resource.
  bool get isUnlimited => (usageLimit ?? -1) < 0;

  /// Returs the [usageLimit] as percentile of [currentUsage].
  double usageAsPercentage() {
    if (usageLimit < 0) return 0;
    return (currentUsage) / (usageLimit * 1.0) * 100.0;
  }
}

/// Shared condition utilities — single source of truth.
/// Used by AddProductController, AddProductPage, and SpecsSection.

/// Returns true if the condition string represents a used device.
/// Covers: Open Box, Like New, Used (Good), Used (Fair).
bool isUsedCondition(String condition) {
  final lower = condition.toLowerCase();
  return lower.contains("open box") ||
      lower.contains("like new") ||
      lower.contains("used") ||
      lower.contains("refurbished");
}
int? parseVideoSourceHeight(String label, {String? url}) {
  final normalized = label.toLowerCase();
  if (normalized.contains('8k')) {
    return 4320;
  }
  if (normalized.contains('4k')) {
    return 2160;
  }

  final progressive = RegExp(
    r'(\d{3,4})\s*p\b',
    caseSensitive: false,
  ).firstMatch(label);
  if (progressive != null) {
    return int.tryParse(progressive.group(1)!);
  }

  final dimensions = RegExp(
    r'(\d{3,5})\s*[x×]\s*(\d{3,5})',
    caseSensitive: false,
  ).firstMatch(label);
  if (dimensions != null) {
    return int.tryParse(dimensions.group(2)!);
  }

  final bareHeight = RegExp(r'^\s*(\d{3,4})\s*$').firstMatch(label);
  if (bareHeight != null) {
    return int.tryParse(bareHeight.group(1)!);
  }

  if (url == null) {
    return null;
  }
  final urlHeight = RegExp(
    r'_(\d{3,4})p?\.mp4(?:[?#]|$)',
    caseSensitive: false,
  ).firstMatch(url);
  return urlHeight == null ? null : int.tryParse(urlHeight.group(1)!);
}

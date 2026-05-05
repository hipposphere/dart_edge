/// Result of a successful Wi-Fi connection request.
final class WifiConnectionResult {
  const WifiConnectionResult({required this.ssid, required this.stdout});

  final String ssid;
  final String stdout;
}

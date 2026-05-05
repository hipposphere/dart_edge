/// Controls whether NetworkManager should rescan before listing Wi-Fi networks.
enum WifiRescanPolicy {
  auto,
  yes,
  no;

  String get wireValue => switch (this) {
    WifiRescanPolicy.auto => 'auto',
    WifiRescanPolicy.yes => 'yes',
    WifiRescanPolicy.no => 'no',
  };
}

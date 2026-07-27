import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('parses negotiated media quality statistics', () {
    final stats = SipMediaStats.fromJson({
      'codecId': 'opus',
      'clockRateHz': 48000,
      'channels': 2,
      'receivedPackets': 990,
      'receivedPacketsLost': 10,
      'sentPackets': 1001,
      'sentPacketsLost': 2,
      'meanJitterUs': 12500,
      'meanRoundTripUs': 85000,
      'jitterBufferLostFrames': 3,
      'jitterBufferDiscardedFrames': 4,
      'jitterBufferEmptyReads': 5,
    });

    expect(stats.codecId, 'opus');
    expect(stats.clockRateHz, 48000);
    expect(stats.channels, 2);
    expect(stats.receivedPacketLossPercent, 1);
    expect(stats.meanJitter, const Duration(microseconds: 12500));
    expect(stats.meanRoundTrip, const Duration(milliseconds: 85));
    expect(stats.jitterBufferLostFrames, 3);
    expect(stats.jitterBufferDiscardedFrames, 4);
    expect(stats.jitterBufferEmptyReads, 5);
  });
}

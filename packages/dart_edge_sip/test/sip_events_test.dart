import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('strips NUL bytes from call event text fields', () {
    final event =
        SipEvent.fromJson({
              'category': 'call',
              'callId': 'call-1\u0000',
              'direction': 'inbound',
              'state': 'inviting',
              'fromUri': 'sip:1000\u0000@pbx.example.com',
              'toUri': 'sip:2000@pbx.example.com\u0000',
              'relatedCallId': 'call-2\u0000',
              'mediaAppId': 'assistant\u0000',
            })
            as SipCallEvent;

    expect(event.callId, 'call-1');
    expect(event.fromUri, 'sip:1000@pbx.example.com');
    expect(event.toUri, 'sip:2000@pbx.example.com');
    expect(event.relatedCallId, 'call-2');
    expect(event.mediaAppId, 'assistant');
  });

  test('strips NUL bytes from nested event metadata', () {
    final event =
        SipEvent.fromJson({
              'category': 'call',
              'callId': 'call-1',
              'direction': 'inbound',
              'state': 'inviting',
              'metadata': {
                'from_uri': 'sip:1000\u0000@pbx.example.com',
                'nested': {'to_uri\u0000': 'sip:2000\u0000@pbx.example.com'},
                'list': [
                  'media\u0000',
                  {'app_id': 'assistant\u0000'},
                ],
              },
            })
            as SipCallEvent;

    expect(event.metadata, {
      'from_uri': 'sip:1000@pbx.example.com',
      'nested': {'to_uri': 'sip:2000@pbx.example.com'},
      'list': [
        'media',
        {'app_id': 'assistant'},
      ],
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  const sourceId = 'test_source';
  const host = 'http://xtream.example.com';
  const username = 'testuser';
  const password = 'testpass';

  late Map<String, dynamic> fixture;
  late _MockHttpClient mockHttp;
  late XtreamClient client;

  setUpAll(() {
    registerFallbackValue(Uri());
    fixture = jsonDecode(
      File('test/fixtures/sample_xtream_response.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  setUp(() {
    mockHttp = _MockHttpClient();
    client = XtreamClient(
      host: host,
      username: username,
      password: password,
      sourceId: sourceId,
      httpClient: mockHttp,
    );
  });

  tearDown(() => client.dispose());

  void stubGet(Object responseBody) {
    when(() => mockHttp.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
              headers: {'content-type': 'application/json'},
            ));
  }

  void stubGetRaw(String body, {int status = 200}) {
    when(() => mockHttp.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(body, status));
  }

  // getLiveStreams/getVodStreams/getAllSeries each fire two concurrent
  // requests (a categories call and the data call) to resolve category
  // names — stubGet's single canned response can't tell those apart, so
  // whichever assertion depends on the resolved name silently gets the
  // wrong payload. This picks the response by the request's `action` query
  // parameter instead.
  void stubGetByAction(Map<String, Object> responsesByAction) {
    when(() => mockHttp.get(any(), headers: any(named: 'headers')))
        .thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.first as Uri;
      final body = responsesByAction[uri.queryParameters['action']];
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  group('XtreamClient.validate', () {
    test('returns true on valid 200 response', () async {
      stubGet(fixture['live_categories']);
      expect(await client.validate(), isTrue);
    });

    test('returns false on 401', () async {
      stubGetRaw('Unauthorized', status: 401);
      expect(await client.validate(), isFalse);
    });

    test('returns false on network error', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenThrow(const SocketException('no network'));
      expect(await client.validate(), isFalse);
    });
  });

  group('XtreamClient.getLiveCategories', () {
    test('returns parsed categories', () async {
      stubGet(fixture['live_categories']);
      final cats = await client.getLiveCategories();
      expect(cats.length, 3);
      expect(cats.first.name, 'News');
      expect(cats.first.id, '1');
    });
  });

  group('XtreamClient.getLiveStreams', () {
    test('returns channels with correct fields', () async {
      stubGetByAction({
        'get_live_categories': fixture['live_categories'],
        'get_live_streams': fixture['live_streams'],
      });
      final channels = await client.getLiveStreams();
      expect(channels.length, 3);
      final bbc = channels.first;
      expect(bbc.name, 'BBC One');
      expect(bbc.logoUrl, 'http://logos.example.com/bbc1.png');
      expect(bbc.tvgId, 'BBC1');
      expect(bbc.streamUrl, contains('/live/$username/$password/101'));
    });

    test('assigns sequential sortOrder', () async {
      stubGetByAction({
        'get_live_categories': fixture['live_categories'],
        'get_live_streams': fixture['live_streams'],
      });
      final channels = await client.getLiveStreams();
      for (var i = 0; i < channels.length; i++) {
        expect(channels[i].sortOrder, i);
      }
    });
  });

  group('XtreamClient.getVodStreams', () {
    test('returns movies with correct fields', () async {
      stubGetByAction({
        'get_vod_categories': fixture['vod_categories'],
        'get_vod_streams': fixture['vod_streams'],
      });
      final movies = await client.getVodStreams();
      expect(movies.length, 2);
      final interstellar = movies.first;
      expect(interstellar.title, 'Interstellar');
      expect(interstellar.year, '2014');
      expect(interstellar.rating, '8.6');
      expect(interstellar.streamUrl, contains('/movie/$username/$password/201.mp4'));
    });

    test('uses container_extension in stream URL', () async {
      stubGetByAction({
        'get_vod_categories': fixture['vod_categories'],
        'get_vod_streams': fixture['vod_streams'],
      });
      final movies = await client.getVodStreams();
      // Second movie uses .mkv
      expect(movies[1].streamUrl, endsWith('.mkv'));
    });
  });

  group('XtreamClient.getAllSeries', () {
    test('returns series with correct fields', () async {
      stubGetByAction({
        'get_series_categories': fixture['series_categories'],
        'get_series': fixture['all_series'],
      });
      final seriesList = await client.getAllSeries();
      expect(seriesList.length, 1);
      final bb = seriesList.first;
      expect(bb.title, 'Breaking Bad');
      expect(bb.genre, contains('Drama'));
      expect(bb.year, '2008');
    });
  });

  group('XtreamClient.getSeriesEpisodes', () {
    test('parses episodes with season and episode numbers', () async {
      stubGet(fixture['series_info']);
      final episodes = await client.getSeriesEpisodes('301');
      expect(episodes.length, 3);

      final pilot = episodes.firstWhere((e) => e.title == 'Pilot');
      expect(pilot.season, 1);
      expect(pilot.episode, 1);
      expect(pilot.streamUrl, contains('/series/$username/$password/1001.mp4'));
    });

    test('assigns correct still URL when available', () async {
      stubGet(fixture['series_info']);
      final episodes = await client.getSeriesEpisodes('301');
      final pilot = episodes.firstWhere((e) => e.title == 'Pilot');
      expect(pilot.stillUrl, contains('bb_s01e01.jpg'));
    });

    test('handles missing still URL gracefully', () async {
      stubGet(fixture['series_info']);
      final episodes = await client.getSeriesEpisodes('301');
      final ep2 = episodes.firstWhere((e) => e.episode == 2);
      expect(ep2.stillUrl, anyOf(isNull, isEmpty));
    });
  });

  group('XtreamClient.buildStreamUrl', () {
    test('builds correct live stream URL', () {
      final url = client.buildStreamUrl('123', 'live');
      expect(url, '$host/live/$username/$password/123.ts');
    });

    test('builds correct movie URL', () {
      final url = client.buildStreamUrl('456', 'movie', ext: 'mp4');
      expect(url, '$host/movie/$username/$password/456.mp4');
    });

    test('appends trailing slash handling', () {
      final clientWithSlash = XtreamClient(
        host: '$host/',
        username: username,
        password: password,
        sourceId: sourceId,
        httpClient: mockHttp,
      );
      final url = clientWithSlash.buildStreamUrl('789', 'live');
      expect(url, '$host/live/$username/$password/789.ts');
      clientWithSlash.dispose();
    });
  });

  group('XtreamClient error handling', () {
    test('throws XtreamException on 403', () async {
      stubGetRaw('Forbidden', status: 403);
      expect(() => client.getLiveStreams(), throwsA(isA<XtreamException>()));
    });

    test('throws XtreamException on invalid JSON', () async {
      stubGetRaw('NOT JSON', status: 200);
      expect(() => client.getLiveStreams(), throwsA(isA<XtreamException>()));
    });
  });
}

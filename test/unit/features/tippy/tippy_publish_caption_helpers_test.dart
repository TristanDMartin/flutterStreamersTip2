import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/tippy/tippy_publish_caption_helpers.dart';

void main() {
  group('normalizeTippyHashtag', () {
    test('adds hash and strips invalid characters', () {
      expect(normalizeTippyHashtag('gaming'), '#gaming');
      expect(normalizeTippyHashtag('#Already'), '#Already');
      expect(normalizeTippyHashtag('  #clip! '), '#clip');
      expect(normalizeTippyHashtag(''), '');
    });
  });

  group('applyTippyHashtags', () {
    const String inputCaption = 'Hook line #oldtag more text';

    test('addAll appends missing tags only', () {
      final String actual = applyTippyHashtags(
        caption: inputCaption,
        allHashtags: <String>['#oldtag', 'newtag', '#fyp'],
        selectedHashtags: <String>['#fyp'],
        mode: TippyHashtagApplyMode.addAll,
      );
      expect(actual, 'Hook line #oldtag more text #newtag #fyp');
    });

    test('addSelected appends only selected tags', () {
      final String actual = applyTippyHashtags(
        caption: inputCaption,
        allHashtags: <String>['#newtag', '#fyp', '#viral'],
        selectedHashtags: <String>['#fyp'],
        mode: TippyHashtagApplyMode.addSelected,
      );
      expect(actual, 'Hook line #oldtag more text #fyp');
    });

    test('replace removes existing tags then adds selected', () {
      final String actual = applyTippyHashtags(
        caption: inputCaption,
        allHashtags: <String>['#newtag', '#fyp'],
        selectedHashtags: <String>['#fyp'],
        mode: TippyHashtagApplyMode.replace,
      );
      expect(actual, 'Hook line more text #fyp');
    });

    test('replace falls back to all tags when none selected', () {
      final String actual = applyTippyHashtags(
        caption: 'Plain caption',
        allHashtags: <String>['#a', '#b'],
        selectedHashtags: const <String>[],
        mode: TippyHashtagApplyMode.replace,
      );
      expect(actual, 'Plain caption #a #b');
    });
  });

  group('extract/strip helpers', () {
    test('extractHashtagsFromText keeps unique order', () {
      final List<String> actual = extractHashtagsFromText(
        'Play #apex #fyp #apex tonight',
      );
      expect(actual, <String>['#apex', '#fyp']);
    });

    test('stripHashtagsFromCaption keeps prose', () {
      expect(
        stripHashtagsFromCaption('Great clip #apex #fyp'),
        'Great clip',
      );
    });
  });
}

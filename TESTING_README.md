## CI test entry points

- Firestore rules (follows): `npm --prefix cloud_functions run test:rules:follows`
- Flutter/unit/widget: `flutter test` (add targets as needed)
- Headless E2E (recommended next): create users A/B, follow/unfollow, mutual, block/mute, verify NetworkView tabs and feed visibility.

## Notes
- Rules tests run against the Firestore emulator with `demo-follows-tests`.
- Ensure Node 18+ available for emulator tooling.
- Keep follow regression cases in `cloud_functions/follows_rules_test.js`. Add new cases when fixing bugs.

bool isApplePrivateRelayEmail(String? email) {
  final String normalized = (email ?? '').trim().toLowerCase();
  return normalized.endsWith('@privaterelay.appleid.com');
}

bool isUsableAppleContactEmail(String? email) {
  final String normalized = (email ?? '').trim();
  return normalized.contains('@');
}

String? appleDisplayNameFromParts({
  String? givenName,
  String? familyName,
}) {
  final String combined = '${givenName ?? ''} ${familyName ?? ''}'.trim();
  return combined.isEmpty ? null : combined;
}

class AppleFirstAuthPersist {
  const AppleFirstAuthPersist({
    required this.persistDisplayName,
    required this.persistEmail,
  });

  final String? persistDisplayName;
  final String? persistEmail;
}

AppleFirstAuthPersist shouldPersistAppleFirstAuthFields({
  String? existingDisplayName,
  String? incomingDisplayName,
  String? existingEmail,
  String? incomingEmail,
}) {
  final String existingName = (existingDisplayName ?? '').trim();
  final String incomingName = (incomingDisplayName ?? '').trim();
  final String existingMail = (existingEmail ?? '').trim();
  final String incomingMail = (incomingEmail ?? '').trim();
  return AppleFirstAuthPersist(
    persistDisplayName:
        existingName.isEmpty && incomingName.isNotEmpty ? incomingName : null,
    persistEmail: existingMail.isEmpty && isUsableAppleContactEmail(incomingMail)
        ? incomingMail
        : null,
  );
}

enum EditableProfileField {
  name,
  bio,
  hashtags;

  String get title {
    switch (this) {
      case EditableProfileField.name:
        return 'Name';
      case EditableProfileField.bio:
        return 'Bio';
      case EditableProfileField.hashtags:
        return 'Hashtags';
    }
  }

  String get key {
    switch (this) {
      case EditableProfileField.name:
        return 'displayName';
      case EditableProfileField.bio:
        return 'bio';
      case EditableProfileField.hashtags:
        return 'hashtags';
    }
  }

  int get maxLength {
    switch (this) {
      case EditableProfileField.name:
        return 30;
      case EditableProfileField.bio:
        return 200;
      case EditableProfileField.hashtags:
        return 100;
    }
  }

  String? get helperText {
    switch (this) {
      case EditableProfileField.name:
        return 'Your nickname can only be changed once every 7 days.';
      case EditableProfileField.bio:
        return 'You can include your pronouns here if you\'d like '
            '(e.g., \'He/him\', \'They/them\', \'She/her\').';
      case EditableProfileField.hashtags:
        return null;
    }
  }
}

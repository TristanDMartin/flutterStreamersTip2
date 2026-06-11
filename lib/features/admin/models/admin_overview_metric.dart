enum AdminOverviewMetric {
  openReports,
  flaggedVideos,
  failedUploads,
  bannedUsers,
  newUsersToday,
  totalUploads,
  processingVideos,
}

extension AdminOverviewMetricX on AdminOverviewMetric {
  String get title {
    switch (this) {
      case AdminOverviewMetric.openReports:
        return 'Open reports';
      case AdminOverviewMetric.flaggedVideos:
        return 'Flagged videos';
      case AdminOverviewMetric.failedUploads:
        return 'Failed uploads';
      case AdminOverviewMetric.bannedUsers:
        return 'Banned users';
      case AdminOverviewMetric.newUsersToday:
        return 'New users today';
      case AdminOverviewMetric.totalUploads:
        return 'Total uploads';
      case AdminOverviewMetric.processingVideos:
        return 'Processing videos';
    }
  }

  String get description {
    switch (this) {
      case AdminOverviewMetric.openReports:
        return 'Reports awaiting moderation review.';
      case AdminOverviewMetric.flaggedVideos:
        return 'Videos flagged for moderation follow-up.';
      case AdminOverviewMetric.failedUploads:
        return 'Upload pipeline failures needing attention.';
      case AdminOverviewMetric.bannedUsers:
        return 'Accounts currently banned from the platform.';
      case AdminOverviewMetric.newUsersToday:
        return 'Accounts created since midnight local time.';
      case AdminOverviewMetric.totalUploads:
        return 'All video documents in the catalog.';
      case AdminOverviewMetric.processingVideos:
        return 'Videos still processing in the pipeline.';
    }
  }

  String get dashboardStatKey {
    switch (this) {
      case AdminOverviewMetric.openReports:
        return 'openReports';
      case AdminOverviewMetric.flaggedVideos:
        return 'flaggedVideos';
      case AdminOverviewMetric.failedUploads:
        return 'failedUploads';
      case AdminOverviewMetric.bannedUsers:
        return 'bannedUsers';
      case AdminOverviewMetric.newUsersToday:
        return 'newUsersToday';
      case AdminOverviewMetric.totalUploads:
        return 'totalUploads';
      case AdminOverviewMetric.processingVideos:
        return 'processingVideos';
    }
  }
}

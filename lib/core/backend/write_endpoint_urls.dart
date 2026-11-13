import 'package:streamers_tip/core/backend/cloudflare_worker_base.dart';
import 'package:streamers_tip/features/content_planning/content_planning_api_client.dart';
import 'package:streamers_tip/features/creator_score/creator_score_service.dart';
import 'package:streamers_tip/features/gamification/gamification_backend_config.dart';

/// Write-capable Cloudflare and worker-backed URLs compiled into this build.
const List<String> kCompileTimeCloudflareWriteUrls = <String>[
  kCloudflareWorkerBaseUrl,
  kGamificationEventsBaseUrl,
  kContentPlanningWorkerBase,
  kCreatorScoreApiBase,
];

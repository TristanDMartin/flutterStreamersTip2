import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Custom widget for displaying official brand icons
class BrandIcon extends StatelessWidget {
  final String platformType;
  final double size;
  final Color? color;

  const BrandIcon({
    super.key,
    required this.platformType,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getPlatformColor(platformType),
      ),
      child: Center(
        child: _buildBrandIcon(platformType, size * 0.6),
      ),
    );
  }

  Widget _buildBrandIcon(String platformType, double iconSize) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return _buildTwitchIcon(iconSize);
      case 'youtube':
        return _buildYouTubeIcon(iconSize);
      case 'kick':
        return _buildKickIcon(iconSize);
      case 'tiktok':
        return _buildTikTokIcon(iconSize);
      case 'facebook':
        return _buildFacebookIcon(iconSize);
      case 'bluesky':
        return _buildBlueskyIcon(iconSize);
      case 'twitter':
      case 'x':
        return _buildXIcon(iconSize);
      case 'discord':
        return _buildDiscordIcon(iconSize);
      case 'instagram':
        return _buildInstagramIcon(iconSize);
      case 'reddit':
        return _buildRedditIcon(iconSize);
      case 'patreon':
        return _buildPatreonIcon(iconSize);
      case 'onlyfans':
        return _buildOnlyFansIcon(iconSize);
      case 'other':
        return Icon(Icons.link, color: Colors.white, size: iconSize);
      case 'whatsapp':
        return _buildWhatsAppIcon(iconSize);
      case 'sms':
        return _buildSMSIcon(iconSize);
      case 'status':
        return _buildStatusIcon(iconSize);
      default:
        return Icon(
          Icons.link,
          color: Colors.white,
          size: iconSize,
        );
    }
  }

  // Twitch Icon (using custom SVG path)
  Widget _buildTwitchIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M2.149 0L.537 4.119V21h5.731V24h3.224l3.045-3.024h4.657l6.269-6.285V0H2.149zm19.164 13.612l-3.483 3.481H12.65l-3.048 3.024V17.09H4.119V2.119H19.313v11.493zm-3.488-5.73v4.918h-2.118V7.882h2.118zm-5.37 0v4.918H9.926V7.882h2.489z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // YouTube Icon
  Widget _buildYouTubeIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Kick Icon (simplified version)
  Widget _buildKickIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          'K',
          style: TextStyle(
            color: const Color(0xFF53FC18),
            fontSize: size * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // TikTok Icon
  Widget _buildTikTokIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Facebook Icon
  Widget _buildFacebookIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Bluesky Icon
  Widget _buildBlueskyIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // X (formerly Twitter) Icon
  Widget _buildXIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Discord Icon
  Widget _buildDiscordIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Instagram Icon
  Widget _buildInstagramIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  Widget _buildPatreonIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M15.386.524c-8.007 0-14.524 6.517-14.524 14.524 0 8.008 6.517 14.524 14.524 14.524 8.008 0 14.524-6.516 14.524-14.524C29.91 7.04 23.393.524 15.386.524M11.17 19.74V7.577h4.216V19.74z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  Widget _buildOnlyFansIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm1.74 4.722c2.826.03 5.043 2.312 5.043 5.14 0 2.826-2.227 5.098-5.053 5.098h-5.039V8.412h5.049zm-1.743 1.828h-2.291v5.624h2.291c1.594 0 2.887-1.287 2.887-2.874 0-1.588-1.293-2.875-2.887-2.875z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Reddit Icon
  Widget _buildRedditIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M12 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0zm5.01 4.744c.688 0 1.25.561 1.25 1.249a1.25 1.25 0 0 1-2.498.056l-2.597-.547-.8 3.747c1.824.07 3.48.632 4.674 1.488.308-.309.73-.491 1.207-.491.968 0 1.754.786 1.754 1.754 0 .716-.435 1.333-1.01 1.614a3.111 3.111 0 0 1 .042.52c0 2.694-3.13 4.87-7.004 4.87-3.874 0-7.004-2.176-7.004-4.87 0-.183.015-.366.043-.534A1.748 1.748 0 0 1 4.028 12c0-.968.786-1.754 1.754-1.754.463 0 .898.196 1.207.49 1.207-.883 2.878-1.43 4.744-1.487l.885-4.182a.342.342 0 0 1 .14-.197.35.35 0 0 1 .238-.042l2.906.617a1.214 1.214 0 0 1 1.108-.701zM9.25 12C8.561 12 8 12.562 8 13.25c0 .687.561 1.248 1.25 1.248.687 0 1.248-.561 1.248-1.249 0-.688-.561-1.249-1.249-1.249zm5.5 0c-.687 0-1.248.561-1.248 1.25 0 .687.561 1.248 1.249 1.248.688 0 1.249-.561 1.249-1.249 0-.687-.562-1.249-1.25-1.249zm-5.466 3.99a.327.327 0 0 0-.231.094.33.33 0 0 0 0 .463c.842.842 2.484.913 2.961.913.477 0 2.105-.056 2.961-.913a.361.361 0 0 0 .029-.463.33.33 0 0 0-.464 0c-.547.533-1.684.73-2.512.73-.828 0-1.979-.196-2.512-.73a.326.326 0 0 0-.232-.095z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // WhatsApp Icon
  Widget _buildWhatsAppIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // SMS Icon
  Widget _buildSMSIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  // Status Icon (WhatsApp Status)
  Widget _buildStatusIcon(double size) {
    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="white">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
        <circle cx="18" cy="6" r="3" fill="white"/>
      </svg>''',
      width: size,
      height: size,
    );
  }

  Color _getPlatformColor(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return const Color(0xFF9146FF);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'kick':
        return const Color(0xFF53FC18);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'bluesky':
        return const Color(0xFF0085FF);
      case 'twitter':
      case 'x':
        return const Color(0xFF000000);
      case 'discord':
        return const Color(0xFF5865F2); // Discord's brand color
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'reddit':
        return const Color(0xFFFF4500);
      case 'patreon':
        return const Color(0xFFFF424D);
      case 'onlyfans':
        return const Color(0xFF00AFF0);
      case 'other':
        return Colors.grey;
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'sms':
        return Colors.green;
      case 'status':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

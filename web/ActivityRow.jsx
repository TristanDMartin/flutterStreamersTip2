/**
 * ActivityRow Component - Web Implementation
 * Individual notification row component
 */

import React from 'react';
import { formatDistanceToNow } from 'date-fns';
import './ActivityRow.css';

const ActivityRow = ({ notification, onTap, isRead }) => {
  const handleClick = () => {
    if (onTap) {
      onTap(notification);
    }
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'follow':
        return '👤';
      case 'like':
        return '❤️';
      case 'comment':
      case 'commentReply':
        return '💬';
      case 'thread_reply':
        return '↩️';
      case 'tag':
        return '🏷️';
      case 'mention':
        return '@';
      case 'system':
        return '🔔';
      case 'newVideo':
        return '🎥';
      case 'milestone':
        return '🏆';
      case 'liveStream':
        return '🔴';
      default:
        return '📌';
    }
  };

  const relativeTime = formatDistanceToNow(notification.createdAt, {
    addSuffix: true,
  });

  const displayName = notification.actorDisplayName || notification.actorUsername || 'Someone';
  const avatarUrl = notification.actorAvatarUrl;

  return (
    <div
      className={`activity-row ${!isRead ? 'activity-row-unread' : ''}`}
      onClick={handleClick}
    >
      <div className="activity-row-avatar">
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt={displayName}
            onError={(e) => {
              e.target.src = '/default-avatar.png';
              e.target.onerror = null; // Prevent infinite loop
            }}
          />
        ) : (
          <div className="activity-row-avatar-placeholder">
            {displayName[0]?.toUpperCase() || '?'}
          </div>
        )}
      </div>

      <div className="activity-row-content">
        <div className="activity-row-header">
          <span className="activity-row-type-icon">
            {getTypeIcon(notification.type)}
          </span>
          <span className="activity-row-name">
            {displayName}
          </span>
          <span className="activity-row-time">{relativeTime}</span>
        </div>
        <div className="activity-row-message">{notification.message}</div>
        {notification.commentText && (
          <div className="activity-row-comment">
            "{notification.commentText}"
          </div>
        )}
      </div>

      {(notification.postThumbnailUrl || notification.videoId) && (
        <div className="activity-row-thumbnail">
          {notification.postThumbnailUrl ? (
            <img
              src={notification.postThumbnailUrl}
              alt="Post thumbnail"
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
          ) : (
            <div className="activity-row-thumbnail-placeholder">
              🎥
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ActivityRow;

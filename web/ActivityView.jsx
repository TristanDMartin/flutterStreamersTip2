/**
 * ActivityView Component - Web Implementation
 * Main activity page displaying real-time notifications
 */

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useActivityNotifications } from './useActivityNotifications';
import { markAllUnreadAsRead, markNotificationAsRead } from './activity-service';
import { useAuth } from './useAuth'; // Adjust import path
import ActivityRow from './ActivityRow';
import './ActivityView.css';

const ActivityView = ({ useLegacyStructure = false }) => {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const { notifications, unreadCount, loading, error } = useActivityNotifications(50, useLegacyStructure);
  const [markingAll, setMarkingAll] = useState(false);

  const handleMarkAllAsRead = async () => {
    if (!currentUser?.uid || markingAll) return;

    setMarkingAll(true);
    try {
      const result = await markAllUnreadAsRead(currentUser.uid, useLegacyStructure);
      if (result.success) {
        console.log(`Marked ${result.count} notifications as read`);
      } else {
        console.error('Failed to mark all as read:', result.error);
        // Could show toast/notification here
      }
    } catch (err) {
      console.error('Error marking all as read:', err);
    } finally {
      setMarkingAll(false);
    }
  };

  const handleNotificationTap = async (notification) => {
    // Mark as read when tapped
    if (!notification.isRead && currentUser?.uid) {
      await markNotificationAsRead(currentUser.uid, notification.id, useLegacyStructure);
    }

    // Navigate based on targetType
    switch (notification.targetType) {
      case 'video':
        if (notification.targetId || notification.videoId) {
          navigate(`/video/${notification.targetId || notification.videoId}`);
        }
        break;
      case 'post':
        if (notification.targetId) {
          navigate(`/post/${notification.targetId}`);
        }
        break;
      case 'thread':
        if (notification.targetId) {
          navigate(`/thread/${notification.targetId}`);
        }
        break;
      case 'user':
        if (notification.actorId) {
          navigate(`/profile/${notification.actorId}`);
        }
        break;
      default:
        // System notifications might not have a target
        break;
    }
  };

  const handleRetry = () => {
    window.location.reload();
  };

  if (loading) {
    return (
      <div className="activity-view activity-view-loading">
        <div className="activity-view-spinner">
          <div className="spinner"></div>
          <p>Loading notifications...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="activity-view activity-view-error">
        <div className="activity-view-error-content">
          <h2>Unable to load notifications</h2>
          <p>{error}</p>
          <button onClick={handleRetry} className="activity-view-retry-button">
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (notifications.length === 0) {
    return (
      <div className="activity-view activity-view-empty">
        <div className="activity-view-empty-content">
          <div className="activity-view-empty-icon">🔔</div>
          <h2>No notifications yet</h2>
          <p>When you get notifications, they'll appear here</p>
        </div>
      </div>
    );
  }

  return (
    <div className="activity-view">
      <div className="activity-view-header">
        <h1 className="activity-view-title">Activity</h1>
        {unreadCount > 0 && (
          <button
            onClick={handleMarkAllAsRead}
            disabled={markingAll}
            className="activity-view-mark-all-button"
          >
            {markingAll ? 'Marking...' : 'Mark all as read'}
          </button>
        )}
      </div>

      <div className="activity-view-list">
        {notifications.map((notification) => (
          <ActivityRow
            key={notification.id}
            notification={notification}
            isRead={notification.isRead}
            onTap={handleNotificationTap}
          />
        ))}
      </div>
    </div>
  );
};

export default ActivityView;

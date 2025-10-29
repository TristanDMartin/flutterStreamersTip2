# Contact Support - Website Implementation Guide

This document provides complete implementation details for the **Contact Support** feature to replicate the Flutter app functionality on the website.

## Overview

The **Contact Support View** allows users to submit support tickets with categories, subject, and message fields.

### Navigation Path
**Menu → Contact Support**

## Firestore Structure

### Support Tickets Collection
```
support_tickets/{ticketId}
```

**Fields:**
- `userId` (String): UID of the user submitting the ticket
- `username` (String): Username from user document
- `displayName` (String): Display name from user document
- `email` (String): Email from Firebase Auth
- `category` (String): Ticket category
- `subject` (String): Brief description (max 100 chars)
- `message` (String): Detailed description (max 1000 chars)
- `status` (String): 'pending' | 'in_progress' | 'resolved' | 'closed'
- `priority` (String): 'high' | 'medium' | 'low'
- `createdAt` (Timestamp): Server timestamp
- `updatedAt` (Timestamp): Server timestamp

### Categories
- General
- Technical Issue
- Account Issue
- Payment/Billing
- Bug Report
- Feature Request
- Report User
- Other

### Priority Logic
- **High**: Bug Report, Technical Issue
- **Medium**: All other categories

## Security Rules

Add these rules to your `firestore.rules`:

```javascript
// Support tickets collection
match /support_tickets/{ticketId} {
  // Users can create tickets
  allow create: if request.auth != null;
  
  // Users can read their own tickets
  // Admins can read all tickets
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.userId || 
    request.auth.uid == 'bU0RxyZ2L4ULAv1Co5L4f825yV73' // Admin UID
  );
  
  // Allow listing for authenticated users
  allow list: if request.auth != null;
  
  // Only admins can update/delete tickets
  allow update: if request.auth != null && 
    request.auth.uid == 'bU0RxyZ2L4ULAv1Co5L4f825yV73';
  allow delete: if request.auth != null && 
    request.auth.uid == 'bU0RxyZ2L4ULAv1Co5L4f825yV73';
}
```

## Flutter Implementation

### View Structure
- **File:** `lib/views/contact_support_view.dart`
- **Navigation:** From Menu → Contact Support

### Features

#### 1. Header Card
- Support icon
- "We're here to help!" message
- Response time information

#### 2. Category Dropdown
- 8 predefined categories
- Required field

#### 3. Subject Field
- Max 100 characters
- Required field

#### 4. Message Field
- Max 1000 characters
- Minimum 20 characters
- Multi-line textarea (8 lines)
- Required field

#### 5. Submit Button
- Loading state during submission
- Disabled during submission

### Form Validation

```dart
// Subject validation
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a subject';
  }
  return null;
}

// Message validation
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a message';
  }
  if (value.length < 20) {
    return 'Message must be at least 20 characters';
  }
  return null;
}
```

### Ticket Submission

```dart
Future<void> _submitTicket() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSubmitting = true);

  try {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You must be logged in to submit a ticket');
      return;
    }

    // Get user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();

    // Create support ticket
    await FirebaseFirestore.instance.collection('support_tickets').add({
      'userId': user.uid,
      'username': userData?['username'] ?? 'Unknown',
      'displayName': userData?['displayName'] ?? user.displayName ?? 'Unknown',
      'email': user.email ?? '',
      'category': _selectedCategory,
      'subject': _subjectController.text,
      'message': _messageController.text,
      'status': 'pending',
      'priority': _selectedCategory == 'Bug Report' ||
              _selectedCategory == 'Technical Issue'
          ? 'high'
          : 'medium',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _showSuccess();

    // Clear form
    _subjectController.clear();
    _messageController.clear();
    setState(() {
      _selectedCategory = 'General';
    });
  } catch (e) {
    _showError('Failed to submit ticket: $e');
  } finally {
    setState(() => _isSubmitting = false);
  }
}
```

## Website Implementation

### React Component Structure

```jsx
import React, { useState, useEffect } from 'react';
import { collection, addDoc, doc, getDoc } from 'firebase/firestore';
import { auth, db } from './firebase';
import './ContactSupport.css';

const ContactSupport = () => {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState('General');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [errors, setErrors] = useState({});

  const categories = [
    'General',
    'Technical Issue',
    'Account Issue',
    'Payment/Billing',
    'Bug Report',
    'Feature Request',
    'Report User',
    'Other'
  ];

  const validate = () => {
    const newErrors = {};
    
    if (!subject.trim()) {
      newErrors.subject = 'Please enter a subject';
    } else if (subject.length > 100) {
      newErrors.subject = 'Subject must be less than 100 characters';
    }
    
    if (!message.trim()) {
      newErrors.message = 'Please enter a message';
    } else if (message.length < 20) {
      newErrors.message = 'Message must be at least 20 characters';
    } else if (message.length > 1000) {
      newErrors.message = 'Message must be less than 1000 characters';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validate()) return;
    
    setIsSubmitting(true);

    try {
      const user = auth.currentUser;
      if (!user) {
        alert('You must be logged in to submit a ticket');
        return;
      }

      // Get user data
      const userDoc = await getDoc(doc(db, 'users', user.uid));
      const userData = userDoc.data();

      // Determine priority
      const isHighPriority = selectedCategory === 'Bug Report' || 
                             selectedCategory === 'Technical Issue';

      // Create support ticket
      await addDoc(collection(db, 'support_tickets'), {
        userId: user.uid,
        username: userData?.username || 'Unknown',
        displayName: userData?.displayName || user.displayName || 'Unknown',
        email: user.email || '',
        category: selectedCategory,
        subject: subject,
        message: message,
        status: 'pending',
        priority: isHighPriority ? 'high' : 'medium',
        createdAt: new Date(),
        updatedAt: new Date()
      });

      alert('✅ Ticket submitted successfully!');
      
      // Clear form
      setSubject('');
      setMessage('');
      setSelectedCategory('General');
    } catch (error) {
      console.error('Error submitting ticket:', error);
      alert('❌ Failed to submit ticket: ' + error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="contact-support-container">
      <div className="header-card">
        <div className="support-icon">🎧</div>
        <h1>We're here to help!</h1>
        <p>Submit a ticket and we'll get back to you soon</p>
      </div>

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="category">Category *</label>
          <select
            id="category"
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="dropdown"
          >
            {categories.map(cat => (
              <option key={cat} value={cat}>{cat}</option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="subject">Subject *</label>
          <input
            id="subject"
            type="text"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            placeholder="Brief description of your issue"
            maxLength={100}
            className={errors.subject ? 'error' : ''}
          />
          {errors.subject && <span className="error-message">{errors.subject}</span>}
        </div>

        <div className="form-group">
          <label htmlFor="message">Message *</label>
          <textarea
            id="message"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Please provide detailed information about your issue..."
            rows={8}
            maxLength={1000}
            className={errors.message ? 'error' : ''}
          />
          {errors.message && <span className="error-message">{errors.message}</span>}
          <div className="char-count">
            {message.length}/1000 characters
          </div>
        </div>

        <button
          type="submit"
          disabled={isSubmitting}
          className="submit-button"
        >
          {isSubmitting ? 'Submitting...' : 'Submit Ticket'}
        </button>
      </form>

      <div className="info-box">
        <span className="info-icon">ℹ️</span>
        <span>Response time is typically within 24-48 hours</span>
      </div>
    </div>
  );
};

export default ContactSupport;
```

### CSS Styling

```css
/* ContactSupport.css */

.contact-support-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 40px 20px;
  background: linear-gradient(135deg, #6633CC 0%, #1A1A4D 100%);
  min-height: 100vh;
}

.header-card {
  background: linear-gradient(135deg, #9248D2 0%, #7768DF 100%);
  border-radius: 16px;
  padding: 40px;
  text-align: center;
  color: white;
}

.support-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.header-card h1 {
  font-size: 24px;
  font-weight: bold;
  margin: 0 0 8px 0;
}

.header-card p {
  font-size: 14px;
  opacity: 0.9;
  margin: 0;
}

form {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 16px;
  padding: 32px;
  margin-top: 32px;
}

.form-group {
  margin-bottom: 24px;
}

.form-group label {
  display: block;
  color: rgba(255, 255, 255, 0.9);
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 8px;
}

.dropdown,
input[type="text"],
textarea {
  width: 100%;
  padding: 16px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 12px;
  color: white;
  font-size: 16px;
}

.dropdown option {
  background: #6137EB;
  color: white;
}

input::placeholder,
textarea::placeholder {
  color: rgba(255, 255, 255, 0.5);
}

input:focus,
textarea:focus {
  outline: none;
  border-color: #9248D2;
  border-width: 2px;
}

textarea {
  resize: vertical;
  min-height: 120px;
}

.error {
  border-color: #ef4444 !important;
}

.error-message {
  display: block;
  color: #ef4444;
  font-size: 12px;
  margin-top: 4px;
}

.char-count {
  color: rgba(255, 255, 255, 0.6);
  font-size: 12px;
  text-align: right;
  margin-top: 4px;
}

.submit-button {
  width: 100%;
  padding: 16px;
  background: #9248D2;
  color: white;
  border: none;
  border-radius: 12px;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  margin-top: 32px;
  transition: background 0.3s;
}

.submit-button:hover:not(:disabled) {
  background: #7d3fc0;
}

.submit-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.info-box {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  margin-top: 16px;
  color: rgba(255, 255, 255, 0.8);
  font-size: 12px;
}

.info-icon {
  font-size: 20px;
}
```

### JavaScript (Vanilla JS) Version

```javascript
// contactSupport.js

const categories = [
  'General',
  'Technical Issue',
  'Account Issue',
  'Payment/Billing',
  'Bug Report',
  'Feature Request',
  'Report User',
  'Other'
];

let selectedCategory = 'General';
let subject = '';
let message = '';
let isSubmitting = false;

function validateForm() {
  const errors = {};
  
  if (!subject.trim()) {
    errors.subject = 'Please enter a subject';
  } else if (subject.length > 100) {
    errors.subject = 'Subject must be less than 100 characters';
  }
  
  if (!message.trim()) {
    errors.message = 'Please enter a message';
  } else if (message.length < 20) {
    errors.message = 'Message must be at least 20 characters';
  } else if (message.length > 1000) {
    errors.message = 'Message must be less than 1000 characters';
  }
  
  // Display errors
  displayErrors(errors);
  
  return Object.keys(errors).length === 0;
}

function displayErrors(errors) {
  // Remove existing errors
  document.querySelectorAll('.error-message').forEach(el => el.remove());
  
  // Add new errors
  Object.entries(errors).forEach(([field, message]) => {
    const fieldElement = document.getElementById(field);
    if (fieldElement) {
      fieldElement.classList.add('error');
      const errorDiv = document.createElement('span');
      errorDiv.className = 'error-message';
      errorDiv.textContent = message;
      fieldElement.parentElement.appendChild(errorDiv);
    }
  });
}

async function submitTicket(e) {
  e.preventDefault();
  
  if (!validateForm()) return;
  
  isSubmitting = true;
  updateSubmitButton();

  try {
    const user = firebase.auth().currentUser;
    if (!user) {
      alert('You must be logged in to submit a ticket');
      return;
    }

    // Get user data
    const userDoc = await db.collection('users').doc(user.uid).get();
    const userData = userDoc.data();

    // Determine priority
    const isHighPriority = selectedCategory === 'Bug Report' || 
                           selectedCategory === 'Technical Issue';

    // Create support ticket
    await db.collection('support_tickets').add({
      userId: user.uid,
      username: userData?.username || 'Unknown',
      displayName: userData?.displayName || user.displayName || 'Unknown',
      email: user.email || '',
      category: selectedCategory,
      subject: subject,
      message: message,
      status: 'pending',
      priority: isHighPriority ? 'high' : 'medium',
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    });

    alert('✅ Ticket submitted successfully!');
    
    // Clear form
    subject = '';
    message = '';
    selectedCategory = 'General';
    document.getElementById('subject').value = '';
    document.getElementById('message').value = '';
    document.getElementById('category').value = 'General';
  } catch (error) {
    console.error('Error submitting ticket:', error);
    alert('❌ Failed to submit ticket: ' + error.message);
  } finally {
    isSubmitting = false;
    updateSubmitButton();
  }
}

function updateSubmitButton() {
  const button = document.getElementById('submit-button');
  if (button) {
    button.disabled = isSubmitting;
    button.textContent = isSubmitting ? 'Submitting...' : 'Submit Ticket';
  }
}

// Event listeners
document.getElementById('category').addEventListener('change', (e) => {
  selectedCategory = e.target.value;
});

document.getElementById('subject').addEventListener('input', (e) => {
  subject = e.target.value;
  const errorMessage = e.target.parentElement.querySelector('.error-message');
  if (errorMessage) errorMessage.remove();
  e.target.classList.remove('error');
});

document.getElementById('message').addEventListener('input', (e) => {
  message = e.target.value;
  const errorMessage = e.target.parentElement.querySelector('.error-message');
  if (errorMessage) errorMessage.remove();
  e.target.classList.remove('error');
  document.getElementById('char-count').textContent = message.length + '/1000 characters';
});

document.getElementById('support-form').addEventListener('submit', submitTicket);
```

## Testing Checklist

- [ ] Display contact support form
- [ ] Validate category selection
- [ ] Validate subject field (required, max 100 chars)
- [ ] Validate message field (required, min 20, max 1000 chars)
- [ ] Submit ticket successfully
- [ ] Show success message
- [ ] Show error message on failure
- [ ] Clear form after submission
- [ ] Show loading state during submission
- [ ] Disable submit button during submission
- [ ] Save to Firestore correctly
- [ ] Firestore rules working correctly

## Summary

This Contact Support View allows users to:
1. Select a category for their ticket
2. Enter a brief subject (max 100 characters)
3. Provide detailed message (20-1000 characters)
4. Submit ticket with automatic priority assignment
5. Receive confirmation of submission

The implementation saves tickets to the `support_tickets` Firestore collection with user information, category, priority, and timestamps. Both the Flutter app and website can access the same data structure for cross-platform consistency.


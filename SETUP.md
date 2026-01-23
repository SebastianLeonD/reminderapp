# Reminder App Setup Guide

## Overview
This project consists of two parts:
1. **n8n API Workflow** - Handles API requests from the iOS app
2. **SwiftUI iOS App** - Native iPhone app for managing reminders

## Part 1: n8n API Workflow Setup

### Step 1: Import the Workflow
1. Open your n8n instance at `https://mac-mini.n8nworkflowssebox.uk`
2. Go to **Workflows**
3. Click **Import from File**
4. Select `Reminders API.json`

### Step 2: Configure the API Key
1. Open the imported workflow
2. Click on the **"Parse & Validate Request"** node
3. Find this line in the code:
   ```javascript
   const VALID_API_KEY = 'YOUR_SECRET_API_KEY_HERE';
   ```
4. Replace with your chosen secret key (e.g., a random string like `rem1nder-4pp-k3y-2024`)
5. **Save the workflow**

### Step 3: Activate the Workflow
1. Toggle the workflow to **Active** (top right)
2. The webhook will be available at:
   ```
   https://mac-mini.n8nworkflowssebox.uk/webhook/api/reminders
   ```

### Step 4: Test the API
Test with curl:
```bash
# List all reminders
curl -X GET "https://mac-mini.n8nworkflowssebox.uk/webhook/api/reminders" \
  -H "x-api-key: YOUR_SECRET_API_KEY_HERE"

# Get specific reminder
curl -X GET "https://mac-mini.n8nworkflowssebox.uk/webhook/api/reminders/1" \
  -H "x-api-key: YOUR_SECRET_API_KEY_HERE"

# Mark complete
curl -X POST "https://mac-mini.n8nworkflowssebox.uk/webhook/api/reminders/1/complete" \
  -H "x-api-key: YOUR_SECRET_API_KEY_HERE"
```

---

## Part 2: iOS App Setup

### Step 1: Create Xcode Project
1. Open Xcode
2. File → New → Project
3. Choose **iOS → App**
4. Settings:
   - Product Name: `ReminderApp`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests"
5. Click **Create**

### Step 2: Replace Generated Files
1. Delete the auto-generated files in Xcode (ContentView.swift, ReminderAppApp.swift)
2. Drag the following folders from `ReminderApp/ReminderApp/` into your Xcode project:
   - `Models/`
   - `Services/`
   - `Stores/`
   - `Views/`
   - `ReminderAppApp.swift`
   - `Info.plist`

### Step 3: Configure API Settings
1. Open `Services/APIService.swift`
2. Update these values:
   ```swift
   static let baseURL = "https://mac-mini.n8nworkflowssebox.uk/webhook/api/reminders"
   static let apiKey = "YOUR_SECRET_API_KEY_HERE"  // Same key from n8n
   ```

### Step 4: Configure Info.plist
In Xcode, select your target → Info tab, add:
- `Privacy - Microphone Usage Description`: "This app uses the microphone for voice input"
- `Privacy - Speech Recognition Usage Description`: "This app uses speech recognition to convert voice to text"

### Step 5: Update Create Reminder Webhook
1. Open `Views/CreateReminderView.swift`
2. Find the `sendReminder()` function
3. Update the webhook URL to match your Telegram bot webhook:
   ```swift
   let webhookURL = "https://mac-mini.n8nworkflowssebox.uk/webhook/65e7a10e-27b7-4621-84ed-3d489ef5e2d4"
   ```
4. Update the chat ID with your Telegram chat ID (find this from your existing reminders in Google Sheets)

### Step 6: Run on iPhone
1. Connect your iPhone to your Mac
2. In Xcode, select your iPhone as the run target
3. Click **Run** (or Cmd+R)
4. Trust the developer certificate on your iPhone:
   - Settings → General → VPN & Device Management → Trust

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/reminders` | List all reminders |
| GET | `/api/reminders?category=homework` | Filter by category |
| GET | `/api/reminders?priority=high` | Filter by priority |
| GET | `/api/reminders?upcoming=true` | Only upcoming reminders |
| GET | `/api/reminders?completed=false` | Only incomplete |
| GET | `/api/reminders/:id` | Get single reminder |
| PUT | `/api/reminders/:id` | Update reminder |
| DELETE | `/api/reminders/:id` | Delete reminder |
| POST | `/api/reminders/:id/complete` | Mark as completed |

### Request Headers
```
x-api-key: YOUR_SECRET_API_KEY_HERE
Content-Type: application/json
```

### Update Reminder Body (PUT)
```json
{
  "title": "New title",
  "description": "New description",
  "category": "homework",
  "priority": "high"
}
```

---

## App Features

- **Today View**: See today's reminders and overdue items
- **All Reminders**: Browse all reminders with filters
- **Create**: Voice or text input to create new reminders
- **Quick Actions**:
  - Swipe right → Mark complete
  - Swipe left → Delete
- **Edit**: Tap a reminder to edit details
- **Pull to Refresh**: Sync with n8n

---

## Troubleshooting

### "Unauthorized" Error
- Check that the API key in the iOS app matches the n8n workflow
- Ensure the n8n workflow is active

### Reminders Not Loading
- Check your Cloudflare tunnel is running
- Verify n8n is running on your Mac Mini
- Check the base URL in APIService.swift

### Voice Input Not Working
- Ensure microphone permissions are granted
- Check speech recognition permissions in Settings

### App Expires After 7 Days
- This is normal for free developer accounts
- Just reconnect your iPhone and run from Xcode again
- Or get Apple Developer Program ($99/year) for TestFlight

# Chat Feature Implementation

## Summary
Implemented chat functionality with weather context integration, aligned iOS frontend with backend `/chat` endpoint.

## Key Changes

### Backend Alignment
- Fixed API format to match `/chat` endpoint
- Removed unsupported `systemPrompt` parameter
- Added message role validation (only `user`/`assistant`)

### Weather Integration
- Auto-inject weather data on first chat message
- Natural conversational format
- One-time injection per conversation

### UI Improvements
- Added Markdown-to-plain-text conversion
- Cleaner message display

### Configuration
- Added `.env` file with `API_KEY` for Anthropic API

## Files Changed
- `ios/The Builders/ChatServiceAPI.swift`
- `ios/The Builders/FeedbackView.swift`
- `.env` (new file)


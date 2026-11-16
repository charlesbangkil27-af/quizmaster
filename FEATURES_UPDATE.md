# QuizMaster feature update

This update adds the requested features to the existing Flutter/Firebase project:

1. Student progress tracker and quiz history.
2. Teacher dashboard with class, student, quiz, submission counts, and average practice score.
3. Class leaderboard based on submitted practice quiz percentages.
4. In-app notifications for new quizzes, class announcements, and students joining a class.

## Firestore changes

- `notifications/{notificationId}` stores recipient-specific in-app notifications.
- `leaderboards/{classId}/entries/{studentId}` stores each student's practice ranking summary.
- New quiz attempts include `teacherId` so the teacher dashboard can query submissions for that teacher.
- `firestore.rules` adds access controls for notifications and leaderboard entries.
- `firestore.indexes.json` adds indexes for notification feeds, leaderboard aggregation, and teacher class notifications.

## Deploy

From the project root:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build web --release --base-href "/quizmaster/"
firebase.cmd deploy --only firestore:rules,firestore:indexes
```

Then commit and push the project to the existing `main` branch. GitHub Actions is configured to build and publish the Flutter web app when changes are pushed.

## Important grading note

QuizMaster currently exposes answer keys to enrolled students and grades practice quizzes in the Flutter client. The leaderboard is therefore a **practice ranking**, not tamper-proof official grading. Do not use these client-calculated scores for high-stakes exams or official grades without moving grading to a trusted backend.

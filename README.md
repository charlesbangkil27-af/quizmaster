# QuizMaster

QuizMaster is a Flutter classroom quiz app using Firebase Authentication and Cloud Firestore.

## Features
- Student and teacher registration/login (accounts activate immediately; no admin approval workflow).
- Teachers create classes and sections and share a six-character join code.
- Students join a class using its code.
- Teachers create multiple-choice quizzes and set an individual timer for every question (5–600 seconds).
- Students answer one question at a time; an unanswered question advances when its timer expires.
- Client-side automatic grading for practice quizzes.
- Firebase Spark-plan compatible: this project does not require Cloud Functions.

## Firebase setup
1. Create/select the Firebase project `quizmaster-capstone` or update `lib/firebase_options.dart` and Android `google-services.json` for your own project.
2. Enable Email/Password under Firebase Authentication.
3. Create the Cloud Firestore database.
4. From the project root, run:

   ```powershell
   firebase.cmd login
   firebase.cmd use quizmaster-capstone
   firebase.cmd deploy --only firestore:rules,firestore:indexes
   flutter pub get
   flutter run
   ```

5. Create a new class after deploying the updated rules. Older classes created before the `classCodes` collection was introduced do not automatically have a matching code document. Recreate those classes or migrate their code documents in Firestore.

## Per-question timer and practice-mode security
The timer is enforced by the Flutter client experience. A modified client could bypass a client-side timer. Also, practice-mode automatic grading intentionally allows enrolled students to read answer-key documents; this is not suitable for high-stakes or proctored examinations. Strong server-enforced timing and private answer keys require a trusted backend, which is outside the Firebase Spark-only setup requested here.

## Run locally

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run -d chrome
```

## Android APK

```powershell
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## GitHub Pages deployment
1. Push this repository to GitHub with the default branch named `main`.
2. In GitHub, open **Settings → Pages** and set the source to **GitHub Actions**.
3. Push to `main` (or run the workflow manually under **Actions**). The workflow builds Flutter Web and deploys it to GitHub Pages.
4. The workflow uses the repository name as the Pages base path automatically.

## Important
Firebase web configuration values are client-side identifiers, not server secrets. Keep service-account keys and private credentials out of the repository. Firestore Security Rules are the access-control boundary.

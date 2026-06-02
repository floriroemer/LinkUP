# LinkUP

LinkUP is a Flutter prototype for a P2P messenger with a local-first account flow.

Current scope:
- Password-gated launch flow
- First-run choice to import an account file or create a new local account
- Optional name and real number fields during account creation
- Simple messenger shell styled with the requested palette

Project note:
- The Flutter SDK is installed locally but was not available on PATH in the default shell.
- The project skeleton has already been generated in this repo. You can run it with the full Flutter path or add Flutter to PATH, then use `flutter run` normally.

Additional service:
- [presence-api\README.md](c:/Users/localadmin/Documents/GIT/LinkUP/presence-api/README.md) contains the Vercel-ready rendezvous API for peer presence and direct availability/history-sync signaling.
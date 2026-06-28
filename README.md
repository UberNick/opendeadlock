# OpenDeadlock

OpenDeadlock is a fan project inspired by the classic turn-based strategy game
Deadlock: Planetary Conquest. The goal is to rebuild the original experience in
a modern, cross-platform form while leaving room for multiplayer, better AI
opponents, mobile play, and refreshed artwork.

The app is built with Flutter so the same codebase can target web, desktop, and
mobile.

## Quick Start for Nick's Local Review

These commands bring up the playable prototype from PR #2 at a predictable local
URL. They are written for a fresh checkout of Nick's upstream repository.

### Requirements

* Flutter SDK: https://docs.flutter.dev/get-started/install
  * CI currently validates with Flutter `3.44.4` on the stable channel.
* Chrome, for the local web runner
* Git
* GitHub CLI, optional but convenient for checking out pull requests:
  https://cli.github.com/

Check the Flutter install with:

```sh
flutter doctor
```

### 1. Check Out PR #2

If you have GitHub CLI installed, this is the shortest path from a fresh checkout
to a browser URL:

```sh
git clone https://github.com/UberNick/opendeadlock.git
cd opendeadlock
gh pr checkout 2
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
```

Then open:

```text
http://127.0.0.1:8080/
```

Flutter usually opens Chrome automatically, but the URL above is the stable local
address for this review session.

If you do not have GitHub CLI, fetch the pull request ref directly:

```sh
git clone https://github.com/UberNick/opendeadlock.git
cd opendeadlock
git fetch origin pull/2/head:review-pr-2
git switch review-pr-2
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
```

Then open `http://127.0.0.1:8080/`.

You can also fetch the review branch directly from the fork:

```sh
git clone https://github.com/UberNick/opendeadlock.git
cd opendeadlock
git fetch https://github.com/hashkanna/opendeadlock.git kanna/playable-prototype
git switch -c review-kanna-playable-prototype FETCH_HEAD
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
```

If port `8080` is already in use, use another port:

```sh
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8081
```

Then open `http://127.0.0.1:8081/`.

### 2. What to Click First

The first screen should be the OpenDeadlock main menu. For a quick review:

* Click **Quick Start** to jump straight into the playable map.
* Click **New Game** to review the setup flow with race, map, opponent, and
  rules options.
* Click **Developer Menu**, then **Legacy References**, to compare the prototype
  against Nick's legacy screenshots.

### 3. Run the Default Branch Locally

Clone the repository and install packages:

```sh
git clone https://github.com/UberNick/opendeadlock.git
cd opendeadlock
flutter pub get
```

Start the Flutter web runner:

```sh
flutter run -d chrome
```

Flutter will print a local URL in the terminal and open Chrome automatically.

For a future pull request, replace `2` in the commands above with the pull
request number you want to review.

### 4. Run a Static Local Web Build

For a predictable local URL, build the web app and serve the generated files:

```sh
flutter build web
python3 -m http.server 8080 -d build/web
```

Then open:

```text
http://127.0.0.1:8080/
```

If port `8080` is already busy, use another port:

```sh
python3 -m http.server 8081 -d build/web
```

Then open `http://127.0.0.1:8081/`.

### Local Troubleshooting

* If Flutter reports no Chrome device, run `flutter config --enable-web` and
  then `flutter devices`.
* If dependency resolution fails after switching branches, run
  `flutter clean && flutter pub get`.
* If the app starts but the browser does not open automatically, open the printed
  localhost URL manually. For the commands above, use `http://127.0.0.1:8080/`.
* If port `8080` is busy, use `--web-port 8081` for `flutter run` or
  `python3 -m http.server 8081 -d build/web` for the static build.

## Current Prototype

This branch includes a playable Flutter prototype that focuses on the first
usable loop:

* New game setup with AI, hotseat, and async multiplayer presets plus race,
  difficulty, opponent, map, and rules options
* Planet map, colony overview, construction, population, resource, and research
  controls
* Turn advancement with colony production, AI turns, reports, and news
* Local save, snapshot, replay, and order package flows
* Main menu entry points for continuing, starting, and loading games
* A legacy screenshot reference gallery for matching the original game UI

Reference screenshots from Nick's email are checked in at:

```text
docs/reference/legacy-screenshots/nick-2026-06-27/
```

## Validation

Before opening a pull request, run:

```sh
flutter test
flutter analyze
flutter build web
```

The generated `build/` directory is ignored by Git and should not be committed.

## Project Roadmap

* Create platform scaffolding
* Build basic interface
* Integrate development tools
* Build map display
* Build world display
* Build colony display
* Create construction UI
* Build game engine and turn behavior
* Incorporate artwork
* Create population rules
* Create resource rules
* Create production rules
* Create movement rules
* Create race rules
* Incorporate sound and music
* Introduce opponents
* Build basic AIs
* Build battle interface
* Create battle and endgame rules
* Create multiplayer interface
* Add multiplayer connectivity
* Build race AIs
* Incorporate video and cutscenes
* Build personality traits

## Links and Resources

### This project

OpenDeadlock Task board:

* https://trello.com/b/80qauJyq/tasks

This page is to manage current work-in-progress and next-up tasks. Completed tasks are archived.

OpenDeadlock Brainstorm board:

* https://trello.com/b/fS0sagJ2/enhancements-brainstorming

This page is for gathering long-term ideas and enhancements.

### Fan and Community resources

Gallius IV Home Page:

* http://galliusiv.com/

Gallius IV Discussion Board:

* http://forum.galliusiv.com/viewforum.php?f=7

Fan Wiki:

* https://deadlock.fandom.com/wiki/Deadlock:_Gallius_IV

### Legacy Project

Legacy OpenDeadlock Decoder Project:

* https://sourceforge.net/p/opendeadlock/decode/ci/default/tree/

Legacy OpenDeadlock Decoder Wiki:

* https://sourceforge.net/p/opendeadlock/decode-wiki

### Original Game

Original game:

* https://www.gog.com/game/deadlock_planetary_conquest

## Supported Platforms

* Windows
* MacOS
* Web
* iOS
* Android

Linux desktop can also be made available. If interested, please let us know in the [forums](http://forum.galliusiv.com/viewforum.php?f=7)

## Contributing

OpenDeadlock is a community project, and contributions are welcome by all. Feel
free to submit Pull Requests, update Trello tickets, or post to the
[Gallius IV forums](http://forum.galliusiv.com/viewforum.php?f=7) if you'd like
to contribute in other ways.

Contributions are especially welcome in the following areas:

* Research / ideas
* Testing
* Developing
* Artwork
* DevOps

See the [Task board](https://trello.com/b/80qauJyq/tasks) and
[Brainstorm board](https://trello.com/b/fS0sagJ2/enhancements-brainstorming)
for details on ongoing work and ideas.

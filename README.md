# reki

Personal media tracker for movies, TV shows, anime, manga, books, and games. Built with Flutter and Supabase, targeting Android, iOS, and desktop from a single codebase.

## Features

- **Unified search** — fans out to TMDB, AniList, Google Books, and RAWG simultaneously
- **Library** — filterable and sortable by media type, status, and rating; multiple layout options
- **Bookmark management** — track status (watching, completed, dropped, on hold, plan to watch), personal rating, and notes
- **Media detail pages** — IMDB-style pages with cast, crew, backdrop, and TMDB ratings
- **Discover / Home** — recently added shelf and category overview
- **Material You theming** — dynamic color on Android, static seed color fallback on iOS/desktop
- **Cloud sync** — bookmarks stored in Supabase and synced across devices when signed in
- **Guest mode** — local bookmarks via shared_preferences, synced on sign-in

## Tech Stack

| Layer | Choice |
|---|---|
| UI / cross-platform | Flutter + Material 3 |
| State management | Riverpod |
| Backend | Supabase (Postgres + Auth) |
| Local cache | shared_preferences |
| HTTP client | Dio |
| Navigation | go_router |
| Fonts | Plus Jakarta Sans (google_fonts) |
| Animations | flutter_animate |
| Image caching | cached_network_image |
| Android theming | dynamic_color |

## APIs

| API | Used for |
|---|---|
| [TMDB](https://www.themoviedb.org/) | Movies & TV shows |
| [AniList](https://anilist.co/) | Anime & manga |
| [Google Books](https://books.google.com/) | Books |
| [RAWG](https://rawg.io/) | Games |

## Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/ramakhilesh22/reki.git
   cd reki
   ```

2. **Copy secrets file and fill in your keys**
   ```bash
   cp secrets.example.json secrets.json
   ```
   Edit `secrets.json` with your Supabase URL/anon key, TMDB bearer token, Google Books API key, and RAWG key.

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run**
   ```bash
   flutter run --dart-define-from-file=secrets.json
   ```

## Database

Create the following tables in your Supabase project (see `supabase/migrations/` for SQL):

- `media_items` — cached metadata (title, poster, genres, runtime, episode count)
- `bookmarks` — per-user status, rating, and notes linked to a media item
- `user_ratings` — standalone ratings (separate from bookmarks)

Enable Row Level Security on `bookmarks` and `user_ratings`.

## Project Structure

```
lib/
├── core/           # Router, theme, API config
├── data/           # Models, repositories, services (TMDB, AniList, Books, RAWG)
├── features/       # auth, search, bookmarks, library, media_detail, home, settings, shell
└── shared/         # Reusable widgets
```

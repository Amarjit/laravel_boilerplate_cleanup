# laravel-cleanup-boilerplate

A fresh `laravel new` install isn't actually empty. You get a welcome page, example tests, an "inspire" console command, a User model wired into auth config, default migrations, seeder code that depends on the factory you're about to delete, and a Vite config that pulls in a font just to render the landing page you'll never ship.

This script strips all of that so you start from an actual blank slate.

## Usage

```sh
./cleanup-boilerplate.sh /path/to/laravel-root
```

The path is required — the script won't guess. It sanity-checks that the target looks like a Laravel root (`artisan` + `composer.json`) before touching anything, and it's safe to re-run.

Optionally set `PROJECT_NAME` to also update `APP_NAME` in `.env` and `.env.example`:

```sh
PROJECT_NAME="My App" ./cleanup-boilerplate.sh /path/to/laravel-root
```

## What it removes (Laravel 13)

- The welcome page and its route
- The example feature and unit tests
- The `inspire` console command
- The default User model, factory, migrations, and their references in the auth config and seeder
- Welcome-page frontend styling (Vite and Tailwind themselves stay)
- The placeholder favicon, stock README, dev sqlite database, and compiled Blade cache

It also switches the session, cache, and queue drivers in the env files away from `database`, since the tables those drivers need came from the migrations that were just deleted. `composer.json` and `composer.lock` are deliberately left alone.

The script is commented — inspect it for the exact file list.

## Version support

The skeleton changes between Laravel majors, so each major gets its own `clean_v<major>()` function, dispatched on the framework version read from `composer.lock`. Currently only **Laravel 13** is covered; anything else exits with an error rather than guessing.

To add support for a new major, write a `clean_v14()` (or whichever) function and register it in the `case` statement at the bottom of the script.

## Caveats

- Runs `sed -i` and `rm` directly against the target — run it on a fresh install or a clean git tree so you can review the diff and roll back if needed.
- GNU sed syntax. On macOS, install `gnu-sed` (`brew install gnu-sed`) or adjust the `-i` flags.

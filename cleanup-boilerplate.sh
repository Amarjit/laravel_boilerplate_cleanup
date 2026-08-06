#!/usr/bin/env bash
#
# cleanup-boilerplate.sh
# Strips Laravel's default skeleton content (example views, tests, User
# model, migrations, etc) from a Laravel install so only the scaffolding
# is left. Safe to re-run.
#
# Usage:
#   ./cleanup-boilerplate.sh <path-to-laravel-root>
#
# The path argument is required. The script will not guess a location.
#
# Version support:
#   Laravel's default skeleton changes between major versions, so cleanup
#   steps live in clean_v<major>() functions, picked by the version in
#   composer.lock. To support a new major (e.g. 14), write clean_v14()
#   and add it to the case statement below.
#
set -euo pipefail

SUPPORTED_VERSIONS="13"

# Set PROJECT_NAME to also update APP_NAME in the env files, e.g:
#   PROJECT_NAME="My App" ./cleanup-boilerplate.sh <path-to-laravel-root>
# Leave unset to skip that step.
PROJECT_NAME="${PROJECT_NAME:-}"

if [[ $# -lt 1 || -z "${1:-}" ]]; then
    echo "ERROR: missing required argument <path-to-laravel-root>." >&2
    echo "Usage: $0 <path-to-laravel-root>" >&2
    exit 1
fi

TARGET_DIR="$1"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: '$TARGET_DIR' is not a directory." >&2
    exit 1
fi

CODE_DIR="$(cd "$TARGET_DIR" && pwd)"

if [[ ! -f "$CODE_DIR/artisan" || ! -f "$CODE_DIR/composer.json" ]]; then
    echo "ERROR: '$CODE_DIR' doesn't look like a Laravel root (no artisan or composer.json)." >&2
    exit 1
fi

cd "$CODE_DIR"

# -----------------------------------------------------------------------
# Detect laravel/framework major version from composer.lock
# -----------------------------------------------------------------------
detect_laravel_major() {
    local version
    version="$(grep -A2 '"name": "laravel/framework"' composer.lock \
        | grep '"version"' \
        | sed -E 's/.*"v?([0-9]+)\..*/\1/')"
    if [[ -z "$version" ]]; then
        echo "ERROR: could not detect laravel/framework version from composer.lock" >&2
        exit 1
    fi
    echo "$version"
}

# -----------------------------------------------------------------------
# Laravel 13.x cleanup
# -----------------------------------------------------------------------
clean_v13() {
    # Default migrations (users, cache, jobs)
    rm -fv database/migrations/*.php

    # User model + factory, and every reference to them.
    # config/auth.php defaults the provider model to App\Models\User;
    # strip the import and leave AUTH_MODEL to the env var only.
    rm -fv app/Models/User.php
    rm -fv database/factories/UserFactory.php
    sed -i \
        -e '/^use App\\Models\\User;$/d' \
        -e "s/env('AUTH_MODEL', User::class)/env('AUTH_MODEL')/" \
        config/auth.php
    echo "removed User references from config/auth.php"

    # Seeder references the User factory we just deleted, so gut it.
    cat > database/seeders/DatabaseSeeder.php <<'PHP'
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        //
    }
}
PHP
    echo "gutted database/seeders/DatabaseSeeder.php"

    # Welcome page and the route/tests tied to it.
    # routes/web.php has to stay (bootstrap/app.php requires it), so empty it.
    rm -fv resources/views/welcome.blade.php
    rm -fv tests/Feature/ExampleTest.php
    rm -fv tests/Unit/ExampleTest.php

    cat > routes/web.php <<'PHP'
<?php

use Illuminate\Support\Facades\Route;
PHP
    echo "emptied routes/web.php"

    # Example "inspire" artisan command. File has to stay too
    # (bootstrap/app.php loads it as the console routes file).
    cat > routes/console.php <<'PHP'
<?php
PHP
    echo "emptied routes/console.php"

    # Frontend placeholders. Keep the files, vite.config.js points at them.
    # app.css keeps just the Tailwind import - the @source lines and the
    # Instrument Sans @theme were only there to style the welcome page.
    # Same font block gets dropped from vite.config.js. Vite itself stays,
    # it's what builds the CSS.
    printf '' > resources/js/app.js
    echo "emptied resources/js/app.js"

    cat > resources/css/app.css <<'CSS'
@import 'tailwindcss';
CSS
    echo "reset resources/css/app.css to bare tailwind import"

    cat > vite.config.js <<'JS'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
    server: {
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
JS
    echo "removed font boilerplate from vite.config.js"

    # Empty placeholder favicon
    rm -fv public/favicon.ico

    # Stock Laravel README
    rm -fv README.md

    # SESSION_DRIVER/CACHE_STORE/QUEUE_CONNECTION default to "database",
    # but that table came from the migrations we just deleted. Switch to
    # file/sync so the app still boots.
    local env_file
    for env_file in .env.example .env; do
        if [[ -f "$env_file" ]]; then
            sed -i \
                -e 's/^SESSION_DRIVER=database$/SESSION_DRIVER=file/' \
                -e 's/^CACHE_STORE=database$/CACHE_STORE=file/' \
                -e 's/^QUEUE_CONNECTION=database$/QUEUE_CONNECTION=sync/' \
                "$env_file"
            echo "updated drivers in $env_file"
        fi
    done

    # Local dev sqlite db (already gitignored, just a runtime artifact)
    rm -fv database/database.sqlite

    # Compiled Blade cache of the views we just deleted
    rm -fv storage/framework/views/*.php

    # APP_NAME - only touched if PROJECT_NAME was passed in.
    # composer.json / composer.lock are left alone, not this script's job.
    if [[ -n "$PROJECT_NAME" ]]; then
        for env_file in .env.example .env; do
            if [[ -f "$env_file" ]]; then
                sed -i "s/^APP_NAME=Laravel$/APP_NAME=\"$PROJECT_NAME\"/" "$env_file"
                echo "updated APP_NAME in $env_file"
            fi
        done
    else
        echo "skipped APP_NAME update (PROJECT_NAME not set)"
    fi
}

# -----------------------------------------------------------------------
# Dispatch on detected version
# -----------------------------------------------------------------------
MAJOR="$(detect_laravel_major)"
echo "Detected laravel/framework major version: $MAJOR"
echo "Cleaning Laravel boilerplate in: $CODE_DIR"

case "$MAJOR" in
    13)
        clean_v13
        ;;
    *)
        echo "ERROR: no cleanup routine for Laravel $MAJOR (supported: $SUPPORTED_VERSIONS)." >&2
        echo "Add a clean_v${MAJOR}() function and register it in the case statement." >&2
        exit 1
        ;;
esac

echo "Done."

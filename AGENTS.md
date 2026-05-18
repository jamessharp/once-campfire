# Agent Development Guide

## Project Shape

Campfire is a single-tenant Rails chat application. It uses Rails from GitHub
main, SQLite, Redis, Resque, Action Cable, Turbo, Stimulus, Action Text, and
importmap-managed JavaScript. Keep changes close to Rails conventions and to the
small, direct style already present in the app.

Important directories:

- `app/models`: domain behavior, often split into small concerns such as
  `Message::Broadcasts`, `User::Role`, and `Membership::Connectable`.
- `app/controllers`: mostly resourceful controllers with authentication and
  authorization handled through concerns.
- `app/views`: server-rendered ERB and Turbo Stream responses.
- `app/javascript`: importmap modules for Stimulus controllers, helpers, models,
  and library code. There is no JavaScript package manager in this repo.
- `app/assets`: Propshaft-served stylesheets, SVGs, images, and sounds.
- `test`: Minitest controller/model/channel/system tests with fixtures.
- `script/admin` and `script/dev`: operational and local-development helpers.

## Setup And Running

- Use the Ruby version in `.ruby-version` (`3.4.5` at the time of writing).
- Run `bin/setup` for local setup. It installs Ruby dependencies, prepares the
  SQLite database under `storage/db`, starts Redis via Docker when needed, and
  installs local CI tools when the package manager supports them.
- Do not run `bin/setup --reset` unless you intend to delete local development
  database and file storage under `storage`.
- Start the web app with `bin/dev` or `bin/rails server`. The `Procfile` also
  documents the production-style processes: web via Thruster, Redis, and Resque
  workers.
- SQLite databases and uploaded development files live under `storage/` and are
  ignored by Git.

## Verification

Prefer focused checks while iterating, then broader checks before handing off:

- Ruby style: `bin/rubocop`
- Rails tests: `bin/rails test`
- One test file: `bin/rails test test/models/message_test.rb`
- System tests: `bin/rails test:system`
- Security checks: `bin/bundler-audit`, `bin/importmap audit`, and `bin/brakeman`
- Full local pipeline: `bin/ci`

`bin/ci` runs setup, Ruby style, GitHub Actions linting (`actionlint`, `zizmor`),
security checks, Rails tests, system tests, seed replanting, and a `gh signoff`
on success. It may be heavier than necessary for small changes.

## Ruby And Rails Conventions

- Follow `rubocop-rails-omakase`; `.rubocop.yml` intentionally only inherits the
  shared Rails style.
- Prefer simple Rails objects and callbacks over new service layers unless the
  surrounding code already has a clear abstraction for the behavior.
- Use existing concerns before adding new cross-cutting code. Controller concerns
  include `Authentication`, `Authorization`, `RoomScoped`, `TrackedRoomVisit`,
  and request/platform/version helpers.
- Authentication state is carried through `Current.user` and `Current.session`.
  Models commonly default ownership to `Current.user`.
- Keep authorization checks close to the controller action. Existing code
  commonly uses `Current.user.can_administer?(record)` and returns
  `head :forbidden` for denied writes.
- Preserve resourceful routing and namespacing. Rooms use STI classes under
  `Rooms::Open`, `Rooms::Closed`, and `Rooms::Direct`.
- When changing persistence, add migrations and let Rails update `db/schema.rb`.
  Do not hand-edit generated schema changes.

## Hotwire, JavaScript, And Assets

- Use Turbo and server-rendered HTML as the default interaction model.
- Stimulus controllers are eager-loaded from `app/javascript/controllers`. Follow
  the existing style: `static targets/classes/values/outlets`, private class
  fields, and small helper modules from `app/javascript/helpers`.
- Import new JavaScript through `config/importmap.rb` or the existing
  `pin_all_from` directories. Do not introduce npm, package.json, bundlers, or a
  Node build step without a deliberate project-level reason.
- Keep reusable browser logic in `app/javascript/models`, `helpers`, or `lib`
  instead of bloating Stimulus controllers.
- CSS is plain, split by component or utility under `app/assets/stylesheets`.
  Reuse existing utility classes and component naming. Avoid unrelated visual
  rewrites.
- Prefer existing SVG/image assets from `app/assets/images` and existing sound
  conventions from `app/assets/sounds`.

## Realtime, Jobs, And External Requests

- Message delivery relies on Turbo broadcasts, Action Cable, Redis, and Resque.
  When changing message or room behavior, check both direct model effects and
  broadcast/job side effects.
- `Room#receive` marks memberships unread and enqueues push delivery. Message
  creation also broadcasts and may trigger bot webhooks.
- Tests disable external network access with WebMock by default. Stub outbound
  HTTP explicitly.
- Be careful around OpenGraph fetching and private-network protection; use the
  existing `RestrictedHTTP::PrivateNetworkGuard` behavior instead of bypassing
  it.

## Testing Patterns

- Tests use Minitest, fixtures, and Rails integration/system test helpers.
- Controller tests commonly call `host! "once.campfire.test"` and use
  `sign_in :fixture_name` from `SessionTestHelper`.
- System tests inherit from `ApplicationSystemTestCase`, use headless Chrome,
  and helpers such as `join_room`, `send_message`, `wait_for_cable_connection`,
  and `dismiss_pwa_install_prompt`.
- Broadcast assertions use helpers in `test/test_helpers/turbo_test_helper.rb`
  and Rails/Action Cable test helpers.
- Add focused tests near the behavior changed. Broaden to system tests when the
  change affects end-user chat flows, browser behavior, or realtime updates.

## Dependency And Workflow Notes

- Do not add gems, JavaScript dependencies, Docker changes, or workflow changes
  casually. This repo keeps its dependency surface small.
- GitHub Actions are intentionally pinned and run with limited permissions. If
  editing `.github/workflows`, run or account for `actionlint` and `zizmor`.
- Follow `CONTRIBUTING.md` for upstream contribution flow: feature ideas and
  uncertain bugs start as discussions; issues represent agreed-upon work.
- Keep generated files, local databases, logs, temp files, and uploaded storage
  out of commits.

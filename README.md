# Sky

A better home for your screenshots on macOS, with a React website built using TanStack Start.

## Repository

```text
apps/
  macos/        Native Swift, SwiftUI, and AppKit app
    Sources/    SkyCore, SkyApp, Sky, and SkySnapshots
    Tests/      Swift unit tests
    Resources/  App bundle resources
    scripts/    macOS app bundler
  web/          TanStack Start + React + TypeScript + Vite
    src/        Routes, components, and styles
    public/     Static assets
scripts/        Compatibility entry points
```

This is a Bun workspace, with Turborepo running tasks across the apps. The native app remains an independent Swift package. Each app owns its build configuration and output. Add shared packages when there is code to share.

## Website

Requires Bun 1.4.4 and Node.js 22.12+ (Node 24 recommended for the Vite tools and production server).

```sh
bun install
bun run dev              # http://localhost:3000
bun run typecheck        # generate the route tree and check TypeScript
bun run build:web        # production web build
bun run start            # production Node server on port 3000
```

`PORT` and `HOST` configure the production server. The website uses TanStack Start's file-based routing and server rendering, with Nitro's Node server adapter. Production output is in `apps/web/.output/`.

The landing page includes a responsive product demo, screenshot previews, keyboard features, privacy details, FAQs, and installation instructions. The Get Sky buttons open source-build instructions because a packaged release has not been published. Update this flow when a downloadable release exists. Demo screenshot content is illustrative. Landscape images come from [Unsplash](apps/web/public/images/README.md).

## macOS app

Requires macOS 14+ and Xcode 26+ (Swift 6.2+). Node and Bun are optional for native-only development.

```sh
./scripts/build-app.sh                  # universal, signed ad hoc
open apps/macos/build/Sky.app
```

Or use the workspace commands:

```sh
bun run dev:macos                      # swift run Sky
bun run build:macos                    # universal app bundle
bun run test:macos                     # Swift unit tests
bun run build                          # build both apps (requires macOS)
bun run check                          # typecheck, build both apps, run tests
bun run format:check                   # check formatting
```

For Swift development, open or work inside `apps/macos`:

```sh
cd apps/macos
swift build
swift test
swift run SkySnapshots out
```

Signing options, app behavior, permissions, and snapshot rendering are documented in the [native app README](apps/macos/README.md). Sky reads your screenshots locally and never uploads them anywhere.

## Task caching

Turborepo caches the web build in `.output/` and restores the generated route tree for typechecking. Development and production servers are persistent, uncached tasks. Native builds and tests always run: signing depends on the local keychain, and Swift tests exercise local macOS services. `CONFIG` and `SIGN_IDENTITY` pass through to the native bundler, so `CONFIG=debug bun run build:macos` and Developer ID signing still work.

Commit `bun.lock` with dependency changes. Use `bun install --frozen-lockfile` for reproducible installs. Local Turbo caches are ignored by Git.

## License

MIT. See [LICENSE](LICENSE).

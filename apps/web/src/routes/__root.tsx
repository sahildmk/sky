import {
  createRootRoute,
  HeadContent,
  Outlet,
  Scripts,
} from '@tanstack/react-router'
import stylesheet from '../styles.css?url'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'Sky — A little home for your screenshots' },
      {
        name: 'description',
        content:
          'Your screenshots, right where you need them. Sky is a free, open-source macOS app that keeps your recent captures in a quiet shelf at the top of your screen.',
      },
      { name: 'theme-color', content: '#f8fafb' },
      {
        property: 'og:title',
        content: 'Sky — A little home for your screenshots',
      },
      {
        property: 'og:description',
        content:
          'Capture. Grab. Carry on. A free, native screenshot shelf for your Mac.',
      },
      { property: 'og:type', content: 'website' },
    ],
    links: [
      { rel: 'stylesheet', href: stylesheet },
      { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
    ],
  }),
  component: () => (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        <Outlet />
        <Scripts />
      </body>
    </html>
  ),
  notFoundComponent: () => (
    <main className="not-found">
      <h1>A little off course.</h1>
      <p>This page doesn’t exist.</p>
      <a href="/">Back to Sky ↗</a>
    </main>
  ),
})

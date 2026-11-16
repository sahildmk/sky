import { createFileRoute } from '@tanstack/react-router'
import {
  ArrowDown,
  ArrowDownToLine,
  ArrowUpRight,
  Check,
  Code2,
  Keyboard,
  LockKeyhole,
  Plus,
  Scan,
  Sparkles,
} from 'lucide-react'
import { useRef } from 'react'
import { AppleIcon, SkyMark } from '../components/brand'
import { InstallDialog } from '../components/install-dialog'
import { ShelfDemo } from '../components/shelf-demo'

export const Route = createFileRoute('/')({ component: LandingPage })

const questions = [
  [
    'Do I need to learn a new screenshot shortcut?',
    'No. Keep using ⇧⌘3, ⇧⌘4, or ⇧⌘5. Sky watches the folder where macOS saves your screenshots and puts each new capture on the shelf.',
  ],
  [
    'Where do my screenshots go?',
    'Where macOS already saves them. Sky reads that folder and shows your recent captures on the shelf. Your files stay on your Mac.',
  ],
  [
    'Does Sky upload anything?',
    'No. Sky never uploads your screenshots, and there’s no account to create.',
  ],
  [
    'Which Macs does Sky work on?',
    'Sky runs on macOS 26 Tahoe or later, on Apple silicon and Intel Macs. Building from source requires Xcode 26 or later.',
  ],
  [
    'Is Sky really free?',
    'Yes. Sky is open source under the MIT license, and the code is on GitHub.',
  ],
] as const

function LandingPage() {
  const install = useRef<HTMLDialogElement>(null)
  function getSky() {
    install.current?.showModal()
  }

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header page-width">
        <a className="brand" href="#" aria-label="Sky home">
          <SkyMark />
          <span>sky</span>
        </a>
        <nav aria-label="Main navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#details">Details</a>
          <a
            href="https://github.com/sahildmk/sky"
            target="_blank"
            rel="noreferrer"
          >
            GitHub
            <ArrowUpRight size={13} />
          </a>
        </nav>
        <button className="button button-small button-dark" onClick={getSky}>
          Get Sky
          <ArrowDownToLine size={14} />
        </button>
      </header>
      <main id="main">
        <section className="hero page-width" aria-labelledby="hero-title">
          <h1 id="hero-title">
            Stop digging for screenshots.
            <br />
            <span>Keep them on a shelf.</span>
          </h1>
          <p className="hero-description">
            Sky puts every new screenshot on a shelf at the top of your
            <br className="desktop-break" /> screen, ready to drag, paste, or
            preview.
          </p>
          <div className="hero-actions">
            <button className="button button-dark" onClick={getSky}>
              <AppleIcon />
              Get Sky for Mac
              <ArrowDownToLine size={16} />
            </button>
            <a className="button button-plain" href="#demo">
              See it in action
              <ArrowDown size={15} />
            </a>
          </div>
          <p className="compatibility">
            Free and open source<span>·</span>macOS 26 or later
          </p>
          <ShelfDemo />
        </section>
        <div className="quiet-benefits page-width">
          <span>
            <Check size={14} />
            Your usual shortcuts
          </span>
          <span>
            <Check size={14} />
            Copied on capture
          </span>
          <span>
            <Check size={14} />
            No account, no uploads
          </span>
          <span>
            <Check size={14} />
            Native Mac app
          </span>
        </div>
        <section
          className="how-section page-width section-space"
          id="how-it-works"
          aria-labelledby="how-title"
        >
          <div className="section-heading">
            <div>
              <p className="eyebrow">How it works</p>
              <h2 id="how-title">
                From screenshot to
                <br />
                where you need it.
              </h2>
            </div>
          </div>
          <div className="steps">
            <article>
              <div className="step-visual shortcut-visual">
                <kbd>⇧</kbd>
                <kbd>⌘</kbd>
                <kbd>4</kbd>
                <span className="capture-crosshair">
                  <Scan size={25} strokeWidth={1.3} />
                </span>
              </div>
              <div className="step-title">
                <span>01</span>
                <h3>Capture as usual.</h3>
              </div>
              <p>
                Take a screenshot with ⇧⌘3, ⇧⌘4, or ⇧⌘5, the way you already do.
              </p>
            </article>
            <article>
              <div className="step-visual mini-shelf-visual">
                <div className="mini-shot shot-back" />
                <div className="mini-shot shot-front">
                  <img src="/images/mountains.jpg" alt="" loading="lazy" />
                </div>
                <div className="copied-chip">
                  <Check size={12} />
                  Copied to clipboard
                </div>
              </div>
              <div className="step-title">
                <span>02</span>
                <h3>It lands on the shelf.</h3>
              </div>
              <p>Sky adds it to the shelf and copies it to your clipboard.</p>
            </article>
            <article>
              <div className="step-visual drag-visual">
                <div className="drag-shot">
                  <img src="/images/lake.jpg" alt="" loading="lazy" />
                  <MouseCursor />
                </div>
                <span className="drag-trail" />
                <div className="drop-target">
                  <Plus size={23} strokeWidth={1.4} />
                </div>
              </div>
              <div className="step-title">
                <span>03</span>
                <h3>Drag, paste, or preview.</h3>
              </div>
              <p>
                Drag it into a message, paste it into a doc, or press Space to
                look closer.
              </p>
            </article>
          </div>
        </section>
        <section
          className="details-section page-width section-space"
          id="details"
          aria-labelledby="details-title"
        >
          <div className="section-heading">
            <div>
              <p className="eyebrow">Details</p>
              <h2 id="details-title">
                Small app.
                <br />
                Careful details.
              </h2>
            </div>
          </div>
          <div className="details-grid">
            <article className="keyboard-card">
              <div className="feature-copy">
                <Keyboard size={21} strokeWidth={1.5} />
                <h3>Keyboard first.</h3>
                <p>
                  Open the shelf from any app, then preview and copy without
                  touching the mouse.
                </p>
              </div>
              <div className="keyboard-ui">
                <div className="key-combo">
                  <kbd>⇧</kbd>
                  <kbd>⌘</kbd>
                  <kbd>6</kbd>
                  <span>Open the shelf</span>
                </div>
                <div className="keyboard-actions">
                  <span>
                    <kbd>←</kbd>
                    <kbd>→</kbd>Navigate
                  </span>
                  <span>
                    <kbd>space</kbd>Preview
                  </span>
                  <span>
                    <kbd>↵</kbd>Copy
                  </span>
                </div>
              </div>
            </article>
            <article className="privacy-card">
              <LockKeyhole size={22} strokeWidth={1.5} />
              <h3>Stays on your Mac.</h3>
              <p>
                Sky never uploads your screenshots, and there’s no account to
                create.
              </p>
              <div className="local-badge">
                <span className="live-dot" />
                Works offline
              </div>
            </article>
            <article className="native-card">
              <div>
                <Sparkles size={22} strokeWidth={1.5} />
                <h3>A native Mac app.</h3>
                <p>
                  Built with Swift and SwiftUI, with Liquid Glass on macOS 26.
                  It lives in your menu bar.
                </p>
              </div>
              <div className="native-art" aria-hidden="true">
                <div className="native-orbit" />
                <SkyMark />
              </div>
            </article>
            <article className="quiet-card">
              <div className="edge-illustration" aria-hidden="true">
                <span />
                <div>
                  <ArrowDown size={17} />
                </div>
              </div>
              <div>
                <h3>Hidden until you need it.</h3>
                <p>
                  The shelf tucks itself away. Rest your pointer at the top edge
                  of the screen to bring it back.
                </p>
              </div>
            </article>
          </div>
        </section>
        <section
          className="faq-section page-width section-space"
          aria-labelledby="faq-title"
        >
          <div>
            <p className="eyebrow">FAQ</p>
            <h2 id="faq-title">Before you install.</h2>
          </div>
          <div className="faq-list">
            {questions.map(([question, answer]) => (
              <details key={question}>
                <summary>
                  {question}
                  <Plus size={17} />
                </summary>
                <p>{answer}</p>
              </details>
            ))}
          </div>
        </section>
        <section className="final-cta page-width" aria-labelledby="cta-title">
          <SkyMark />
          <h2 id="cta-title">
            Give your screenshots
            <br />a place to land.
          </h2>
          <button className="button button-dark" onClick={getSky}>
            <AppleIcon />
            Get Sky for Mac
            <ArrowDownToLine size={16} />
          </button>
          <span className="compatibility">
            Free and open source. macOS 26 or later.
          </span>
          <div className="cta-cloud cta-cloud-left" />
          <div className="cta-cloud cta-cloud-right" />
        </section>
      </main>
      <footer className="site-footer page-width">
        <a className="brand" href="#" aria-label="Sky home">
          <SkyMark />
          <span>sky</span>
        </a>
        <span>A shelf for your screenshots.</span>
        <div>
          <a
            href="https://github.com/sahildmk/sky"
            target="_blank"
            rel="noreferrer"
          >
            <Code2 size={15} />
            Source code
            <ArrowUpRight size={12} />
          </a>
          <a
            href="https://github.com/sahildmk/sky/blob/main/LICENSE"
            target="_blank"
            rel="noreferrer"
          >
            MIT License
            <ArrowUpRight size={12} />
          </a>
        </div>
      </footer>
      <InstallDialog ref={install} />
    </>
  )
}

function MouseCursor() {
  return (
    <svg
      className="mouse-cursor"
      width="22"
      height="26"
      viewBox="0 0 22 26"
      aria-hidden="true"
    >
      <path
        d="m3 2 15 13-7 1-3 7-5-21Z"
        fill="#243a4e"
        stroke="white"
        strokeWidth="2"
        strokeLinejoin="round"
      />
    </svg>
  )
}

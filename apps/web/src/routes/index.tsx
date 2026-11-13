import { createFileRoute } from '@tanstack/react-router'
import {
  ArrowDown,
  ArrowDownToLine,
  ArrowUpRight,
  Check,
  Code2,
  Keyboard,
  LockKeyhole,
  MoveUpRight,
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
    'Exactly where they go today. Sky follows the screenshot location in macOS and gives your recent captures a more convenient home on screen. Your files stay on your Mac.',
  ],
  [
    'Does Sky upload anything?',
    'No. Sky reads your local screenshots and never uploads them anywhere. There’s no account to create and no cloud storage to configure.',
  ],
  [
    'Which Macs does Sky work on?',
    'Sky runs on macOS 26 Tahoe or later, on Apple silicon and Intel Macs. Building from source requires Xcode 26 or later.',
  ],
  [
    'Is Sky really free?',
    'Yes. Sky is free and open source under the MIT license. You can explore the code, build the app, and make it your own on GitHub.',
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
          <a href="#details">The little details</a>
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
          <div className="release-note">
            <span className="live-dot" />A little utility for your Mac
            <span className="release-separator">/</span>
            <span>Free & open source</span>
          </div>
          <h1 id="hero-title">
            Your screenshots.
            <br />
            <span>A little more at home.</span>
          </h1>
          <p className="hero-description">
            Meet Sky. A quiet little shelf that keeps your screenshots
            <br className="desktop-break" /> close, so you can capture, grab,
            and carry on.
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
            Made for macOS 26+<span>·</span>All yours. Always local.
          </p>
          <ShelfDemo />
        </section>
        <div className="quiet-benefits page-width">
          <span>
            <Check size={14} />
            Your shortcuts, unchanged
          </span>
          <span>
            <Check size={14} />
            Ready to paste
          </span>
          <span>
            <Check size={14} />
            No accounts. No uploads.
          </span>
          <span>
            <Check size={14} />
            Native to your Mac
          </span>
        </div>
        <section
          className="how-section page-width section-space"
          id="how-it-works"
          aria-labelledby="how-title"
        >
          <div className="section-heading">
            <div>
              <p className="eyebrow">LESS FRICTION, MORE FLOW</p>
              <h2 id="how-title">
                From screenshot to
                <br />
                where you need it.
              </h2>
            </div>
            <p>
              No new habits. No folder archaeology.
              <br />
              Just a small improvement to something
              <br />
              you do every day.
            </p>
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
                Your muscle memory stays. Take a screenshot with the Mac
                shortcuts you already know.
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
                <h3>It’s already there.</h3>
              </div>
              <p>
                A new capture lands on your shelf and copies to your clipboard.
                Ready when you are.
              </p>
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
                <h3>Grab it. Carry on.</h3>
              </div>
              <p>
                Drag it into a message, paste it into a doc, or open a quick
                preview. Back to your day.
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
              <p className="eyebrow">SMALL BY DESIGN</p>
              <h2 id="details-title">
                The little things.
                <br />
                Thought all the way through.
              </h2>
            </div>
            <span className="handwritten">
              Just enough. Never in the way.
              <MoveUpRight size={19} strokeWidth={1} />
            </span>
          </div>
          <div className="details-grid">
            <article className="keyboard-card">
              <div className="feature-copy">
                <Keyboard size={21} strokeWidth={1.5} />
                <h3>A shortcut to your shortcuts.</h3>
                <p>
                  Bring up the shelf from anywhere. Preview, copy, and move on
                  without lifting a finger from the keyboard.
                </p>
              </div>
              <div className="keyboard-ui">
                <div className="key-combo">
                  <kbd>⇧</kbd>
                  <kbd>⌘</kbd>
                  <kbd>6</kbd>
                  <span>At your fingertips.</span>
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
              <h3>
                On your Mac.
                <br />
                And only your Mac.
              </h3>
              <p>
                Your screenshots are yours. Sky never uploads them anywhere. No
                account, no cloud, no fuss.
              </p>
              <div className="local-badge">
                <span className="live-dot" />
                100% local. A little peace of mind.
              </div>
            </article>
            <article className="native-card">
              <div>
                <Sparkles size={22} strokeWidth={1.5} />
                <h3>
                  Feels like it belongs.
                  <br />
                  Because it does.
                </h3>
                <p>
                  Built with Swift and SwiftUI. At home in your menu bar, with
                  Liquid Glass on macOS 26.
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
                <h3>
                  Out of sight.
                  <br />A moment away.
                </h3>
                <p>
                  The shelf tucks itself away. Rest your pointer at the top edge
                  of your screen to bring it back.
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
            <p className="eyebrow">A FEW THINGS YOU MIGHT WONDER</p>
            <h2 id="faq-title">Good questions.</h2>
            <p>A small app. No big mysteries.</p>
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
          <p className="eyebrow">A LITTLE SPACE GOES A LONG WAY</p>
          <h2 id="cta-title">
            Less looking.
            <br />
            More doing.
          </h2>
          <p>Give your screenshots a place to land.</p>
          <button className="button button-dark" onClick={getSky}>
            <AppleIcon />
            Get Sky for Mac
            <ArrowDownToLine size={16} />
          </button>
          <span className="compatibility">
            Free & open source. Made for your Mac.
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
        <span>A little home for your screenshots.</span>
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
        <p>Made with care for the Mac.</p>
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

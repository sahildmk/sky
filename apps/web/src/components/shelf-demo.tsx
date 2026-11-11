import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  Check,
  Copy,
  Expand,
  MousePointer2,
  X,
} from 'lucide-react'
import { useRef, useState } from 'react'

const captures = [
  { name: 'A little inspiration', kind: 'board', time: 'Just now' },
  { name: 'Somewhere worth saving', kind: 'mountains', time: '2 minutes ago' },
  { name: 'The next adventure', kind: 'lake', time: '5 minutes ago' },
] as const

function Capture({ kind }: { kind: (typeof captures)[number]['kind'] }) {
  if (kind !== 'board')
    return (
      <img
        src={`/images/${kind}.jpg`}
        alt={
          kind === 'mountains' ? 'Sunlit mountain peaks' : 'A quiet alpine lake'
        }
        draggable={false}
      />
    )
  return (
    <div className="capture-board" aria-label="An example design moodboard">
      <div className="board-heading">
        a place to begin<span>EXPLORATIONS / 001</span>
      </div>
      <div className="board-art">
        <div />
        <div />
        <div />
      </div>
      <div className="board-footer">
        <span>Less, but a little better.</span>
        <span>↗</span>
      </div>
    </div>
  )
}

export function ShelfDemo() {
  const [pinned, setPinned] = useState(false)
  const [selected, setSelected] = useState(0)
  const [copied, setCopied] = useState(false)
  const [copyError, setCopyError] = useState(false)
  const preview = useRef<HTMLDialogElement>(null)

  async function copyExample() {
    setCopyError(false)
    try {
      const capture = captures[selected]
      const url =
        capture.kind === 'board'
          ? '/images/moodboard.svg'
          : `/images/${capture.kind}.jpg`
      await navigator.clipboard.writeText(
        new URL(url, window.location.origin).href,
      )
      setCopied(true)
    } catch {
      setCopyError(true)
    }
  }

  function openPreview(index: number) {
    setSelected(index)
    setCopied(false)
    setCopyError(false)
    preview.current?.showModal()
  }

  return (
    <>
      <div className="demo-wrap" id="demo">
        <div className="desktop-demo" data-expanded={pinned}>
          <div className="desktop-menubar" aria-hidden="true">
            <div>
              <span className="menu-apple">●</span>
              <b>Finder</b>
              <span>File</span>
              <span>Edit</span>
              <span>View</span>
            </div>
            <div>
              <span>◒</span>
              <span>⌁</span>
              <span>Mon 9:41 AM</span>
            </div>
          </div>
          <div className="wallpaper-cloud cloud-one" />
          <div className="wallpaper-cloud cloud-two" />
          <div className="desktop-greeting" aria-hidden="true">
            Room to think.
          </div>
          <div className="shelf-zone">
            <div
              className="demo-shelf"
              role="group"
              aria-label="Example screenshots. Select one to preview."
            >
              {captures.map((capture, index) => (
                <button
                  className={`shelf-capture capture-${index}`}
                  key={capture.kind}
                  type="button"
                  aria-label={`Preview ${capture.name}`}
                  onClick={() => openPreview(index)}
                >
                  <Capture kind={capture.kind} />
                  <span className="capture-hover">
                    <Expand size={14} /> Preview
                  </span>
                </button>
              ))}
            </div>
            <div className="shelf-caption">
              <span className="status-dot" />3 screenshots. Right at hand.
            </div>
          </div>
          <div className="demo-hint" aria-hidden="true">
            <MousePointer2 size={17} />
            <span>
              A little shelf.
              <br />A lot less searching.
            </span>
          </div>
          <div className="desktop-bottom">
            <span>YOUR DESKTOP, WITH A LITTLE MORE SPACE.</span>
            <span>SKY FOR MAC</span>
          </div>
        </div>
        <div className="demo-controls">
          <span>
            <span className="live-dot" />A little preview of Sky
          </span>
          <button
            className="text-button"
            type="button"
            aria-pressed={pinned}
            onClick={() => setPinned(!pinned)}
          >
            {pinned ? 'Tuck it away' : 'Try the shelf'}
            <ArrowDown size={15} className={pinned ? 'flipped' : ''} />
          </button>
          <span className="demo-desktop-note">
            Hover to unfold. Click to explore.
          </span>
        </div>
      </div>
      <dialog
        className="capture-dialog"
        ref={preview}
        aria-labelledby="capture-title"
        onClick={(event) => {
          if (event.target === event.currentTarget) preview.current?.close()
        }}
      >
        <div className="preview-toolbar">
          <div>
            <h2 id="capture-title">{captures[selected].name}</h2>
            <span>{captures[selected].time} · Example screenshot</span>
          </div>
          <button
            className="icon-button"
            aria-label="Close preview"
            onClick={() => preview.current?.close()}
          >
            <X size={20} />
          </button>
        </div>
        <div className="preview-image">
          <Capture kind={captures[selected].kind} />
        </div>
        <div className="preview-bottom">
          <div>
            <button
              className="icon-button"
              aria-label="Previous example"
              onClick={() => {
                setSelected((selected + 2) % 3)
                setCopied(false)
                setCopyError(false)
              }}
            >
              <ArrowLeft size={18} />
            </button>
            <span>{selected + 1} / 3</span>
            <button
              className="icon-button"
              aria-label="Next example"
              onClick={() => {
                setSelected((selected + 1) % 3)
                setCopied(false)
                setCopyError(false)
              }}
            >
              <ArrowRight size={18} />
            </button>
          </div>
          <button className="text-button" onClick={copyExample}>
            {copied ? <Check size={16} /> : <Copy size={16} />}
            {copied ? 'Link copied' : 'Copy example link'}
          </button>
        </div>
        <p className="sr-only" role="status">
          {copied
            ? 'Example link copied to clipboard.'
            : copyError
              ? 'Clipboard unavailable. You can explore the other examples using the arrow buttons.'
              : ''}
        </p>
        {copyError && (
          <p className="copy-error">
            Your browser couldn’t access the clipboard.
          </p>
        )}
      </dialog>
    </>
  )
}

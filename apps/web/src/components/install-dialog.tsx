import { ArrowUpRight, Check, Copy, X } from 'lucide-react'
import { forwardRef, useState } from 'react'
import { SkyMark } from './brand'

const command =
  'git clone https://github.com/sahildmk/sky.git\ncd sky\n./scripts/build-app.sh\nopen apps/macos/build/Sky.app'

export const InstallDialog = forwardRef<HTMLDialogElement>(
  function InstallDialog(_, ref) {
    const [copied, setCopied] = useState(false)
    const [error, setError] = useState(false)

    async function copy() {
      try {
        await navigator.clipboard.writeText(command)
        setCopied(true)
        setError(false)
      } catch {
        setError(true)
      }
    }

    return (
      <dialog
        className="install-dialog"
        ref={ref}
        aria-labelledby="install-title"
        onClick={(event) => {
          if (event.target === event.currentTarget) event.currentTarget.close()
        }}
      >
        <form method="dialog">
          <button
            className="icon-button close-dialog"
            aria-label="Close installation instructions"
          >
            <X size={20} />
          </button>
        </form>
        <SkyMark />
        <p className="eyebrow">A LITTLE HOME ON YOUR MAC</p>
        <h2 id="install-title">Make room for Sky.</h2>
        <p>
          Sky is free and open source. While we get a packaged release ready,
          you can build it yourself.
        </p>
        <div className="install-requirements">
          <span>macOS 26 or later</span>
          <span>Xcode 26 or later</span>
        </div>
        <div className="code-block">
          <pre>
            <code>{command}</code>
          </pre>
          <button
            className="icon-button"
            aria-label="Copy build commands"
            onClick={copy}
          >
            {copied ? <Check size={17} /> : <Copy size={17} />}
          </button>
        </div>
        <p className="clipboard-status" role="status">
          {error
            ? 'Select the commands above and copy them manually.'
            : copied
              ? 'Commands copied. Paste them into Terminal to get started.'
              : 'Run these commands in Terminal, then allow access to your screenshots folder.'}
        </p>
        <a
          className="text-button source-link"
          href="https://github.com/sahildmk/sky#readme"
          target="_blank"
          rel="noreferrer"
        >
          Read the setup guide
          <ArrowUpRight size={16} />
        </a>
      </dialog>
    )
  },
)

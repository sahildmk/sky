export function SkyMark({ className = '' }: { className?: string }) {
  return (
    <img
      className={`sky-mark ${className}`}
      src="/favicon.svg"
      width="40"
      height="40"
      alt=""
    />
  )
}

export function AppleIcon() {
  return (
    <svg
      width="18"
      height="20"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M17.1 12.6c0-2 1.6-3 1.7-3.1-1-1.5-2.6-1.7-3.2-1.7-1.4-.2-2.8.9-3.5.9s-1.8-.9-3-.9c-1.6 0-3.1.9-3.9 2.3-1.7 2.9-.4 7.3 1.2 9.7.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3.1-.7s1.9.7 3.1.7c1.3 0 2.1-1.2 2.9-2.3.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.6-1-2.6-4.5ZM14.7 6.2c.6-.8 1.1-1.9 1-3-.9.1-2.1.6-2.8 1.4-.6.7-1.2 1.8-1.1 2.9 1 .1 2.2-.5 2.9-1.3Z" />
    </svg>
  )
}

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "var(--font-plus-jakarta-sans)",
          "ui-sans-serif",
          "system-ui",
          "sans-serif",
        ],
      },
      colors: {
        "gh-green": "#047857",
        "gh-green-light": "#059669",
        "gh-green-dark": "#065f46",
        "gh-bg": "#f7f8fa",
        "gh-card": "#ffffff",
        "gh-border": "#e5e7eb",
      },
    },
  },
  plugins: [],
};

# Job Tracker

A clean Next.js job application tracker deployed on Vercel.

## What It Does

- Paste a job post and fill the application form from the text.
- Track applications through saved, applied, interviewing, offer, rejected, and withdrawn.
- Save profile details, experience, and projects for cover-letter drafts.
- Generate simple match scores, tailoring notes, and cover-letter text locally.
- See skill patterns across saved jobs.

## Tech Stack

- Next.js
- React
- TypeScript
- Plain CSS
- Browser `localStorage`
- Vercel

## Run Locally

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Deployment

The app is linked to Vercel and can be deployed with:

```bash
npx vercel deploy --prod --yes
```

Production: https://jobtracker-theta-ebon.vercel.app

## Storage Note

This version intentionally stores job data in the browser. That keeps it simple, private by default, and easy to deploy without a database.

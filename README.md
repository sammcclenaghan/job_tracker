# Job Tracker

A personal job application tracker with AI-powered cover letter generation.

## Features

- **Paste & Parse** — paste a job posting, AI extracts company, title, location, skills, etc.
- **Cover Letter Generation** — generates structured cover letters using your resume and job details
- **Status Workflow** — track applications through saved → applied → interviewing → offer/rejected
- **Dashboard** — filter by status, see all applications at a glance

## Tech Stack

- Ruby on Rails 8.1
- SQLite
- Tailwind CSS
- Stimulus (for instant UI updates)
- OpenRouter API (free models)

## Setup

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:setup

# Add your OpenRouter API key
bin/rails credentials:edit
# Add:
# openrouter:
#   api_key: your-key-here

# Run the server
bin/dev
```

Get an API key at [openrouter.ai/keys](https://openrouter.ai/keys)

## Usage

1. Add your resume at `/resume`
2. Create applications manually or use "Paste & Parse" to extract from job postings
3. Generate cover letters with one click
4. Track status as you progress through the hiring process

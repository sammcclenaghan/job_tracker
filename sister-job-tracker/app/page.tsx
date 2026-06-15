"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";

type Status =
  | "saved"
  | "applied"
  | "interviewing"
  | "offer"
  | "rejected"
  | "withdrawn";
type WorkArrangement = "remote" | "hybrid" | "onsite" | "";
type View =
  | "dashboard"
  | "new-paste"
  | "new-manual"
  | "show"
  | "edit"
  | "skills"
  | "experience"
  | "experience-edit"
  | "settings";

type JobApplication = {
  id: string;
  companyName: string;
  jobTitle: string;
  location: string;
  workArrangement: WorkArrangement;
  salaryRange: string;
  jobDescription: string;
  skills: string[];
  contactEmail: string;
  applicationInstructions: string;
  jobUrl: string;
  status: Status;
  notes: string;
  coverLetter: string;
  matchScore: number;
  matchReason: string;
  projectRecommendations: string[];
  experienceTailoring: string[];
  appliedAt: string;
  createdAt: string;
  updatedAt: string;
};

type ExperienceEntry = {
  id: string;
  entryType: "experience" | "project";
  title: string;
  organization: string;
  location: string;
  dateRange: string;
  technologies: string;
  tags: string;
  details: string;
};

type Profile = {
  name: string;
  email: string;
  phone: string;
  linkedin: string;
  site: string;
};

type AiBusyState = "parse" | "insights" | "cover_letter" | null;

const STATUSES: Status[] = [
  "saved",
  "applied",
  "interviewing",
  "offer",
  "rejected",
  "withdrawn",
];

const STATUS_BADGE: Record<Status, string> = {
  saved: "bg-gray-100 text-gray-700 border border-gray-200",
  applied: "bg-blue-50 text-blue-700 border border-blue-200",
  interviewing: "bg-amber-50 text-amber-700 border border-amber-200",
  offer: "bg-emerald-50 text-emerald-700 border border-emerald-200",
  rejected: "bg-red-50 text-red-700 border border-red-200",
  withdrawn: "bg-gray-100 text-gray-500 border border-gray-200",
};

const SAMPLE_ENTRIES: ExperienceEntry[] = [
  {
    id: "sample-1",
    entryType: "experience",
    title: "Customer Operations Coordinator",
    organization: "Previous role",
    location: "",
    dateRange: "",
    technologies: "Scheduling, email, CRM, reporting",
    tags: "operations, communication",
    details:
      "Coordinated high-volume requests, kept records organized, improved follow-up habits, and communicated clearly with clients and internal teams.",
  },
  {
    id: "sample-2",
    entryType: "project",
    title: "Process cleanup project",
    organization: "",
    location: "",
    dateRange: "",
    technologies: "Spreadsheets, documentation, checklists",
    tags: "documentation",
    details:
      "Turned a messy recurring workflow into a clear checklist, reducing missed steps and making handoffs easier.",
  },
];

const EMPTY_PROFILE: Profile = {
  name: "",
  email: "",
  phone: "",
  linkedin: "",
  site: "",
};

const STORAGE_KEY = "job-tracker-next-data";
const API_KEY_STORAGE_KEY = "job-tracker-openrouter-api-key";

function makeId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function blankApplication(): JobApplication {
  const now = new Date().toISOString();
  return {
    id: makeId(),
    companyName: "",
    jobTitle: "",
    location: "",
    workArrangement: "",
    salaryRange: "",
    jobDescription: "",
    skills: [],
    contactEmail: "",
    applicationInstructions: "",
    jobUrl: "",
    status: "saved",
    notes: "",
    coverLetter: "",
    matchScore: 0,
    matchReason: "",
    projectRecommendations: [],
    experienceTailoring: [],
    appliedAt: "",
    createdAt: now,
    updatedAt: now,
  };
}

function blankEntry(): ExperienceEntry {
  return {
    id: makeId(),
    entryType: "experience",
    title: "",
    organization: "",
    location: "",
    dateRange: "",
    technologies: "",
    tags: "",
    details: "",
  };
}

function capitalize(value: string) {
  if (!value) return value;
  return value[0].toUpperCase() + value.slice(1).toLowerCase();
}

function titleCase(value: string) {
  return value
    .trim()
    .replace(/\s+/g, " ")
    .replace(/\w\S*/g, (word) => word[0].toUpperCase() + word.slice(1).toLowerCase());
}

function formatDate(value: string, opts?: Intl.DateTimeFormatOptions) {
  if (!value) return "--";
  const d = new Date(value);
  if (isNaN(+d)) return "--";
  return d.toLocaleDateString(undefined, opts || { month: "short", day: "numeric" });
}

function extractLine(raw: string, labels: string[]) {
  const lines = raw
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);
  for (const label of labels) {
    const found = lines.find((line) =>
      line.toLowerCase().startsWith(`${label.toLowerCase()}:`)
    );
    if (found) return found.split(":").slice(1).join(":").trim();
  }
  return "";
}

function parseJobPosting(raw: string): Partial<JobApplication> {
  const text = raw.trim();
  const firstLines = text
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 8);
  const company =
    extractLine(text, ["company", "employer", "organization"]) ||
    firstLines.find((line) =>
      /inc|corp|company|ltd|llc|group|agency|school|health|systems/i.test(line)
    ) ||
    "";
  const title =
    extractLine(text, ["title", "job title", "position", "role"]) ||
    firstLines.find((line) =>
      /manager|coordinator|assistant|specialist|analyst|developer|designer|engineer|representative|administrator/i.test(
        line
      )
    ) ||
    firstLines[0] ||
    "";
  const location =
    extractLine(text, ["location"]) ||
    (text.match(/\b(remote|hybrid|onsite|on-site)\b.*?(?:\n|$)/i)?.[0] || "").trim();
  const salary =
    extractLine(text, ["salary", "pay", "compensation"]) ||
    text.match(
      /\$[\d,]+(?:\s*[-–]\s*\$?[\d,]+)?(?:\s*(?:per year|yearly|\/year|\/hr|hourly))?/i
    )?.[0] ||
    "";
  const contactEmail = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0] || "";
  const jobUrl =
    text.match(/https?:\/\/\S+/i)?.[0]?.replace(/[).,]+$/, "") || "";
  const workArrangement = /remote/i.test(text)
    ? "remote"
    : /hybrid/i.test(text)
      ? "hybrid"
      : /on-?site/i.test(text)
        ? "onsite"
        : "";
  const skills = Array.from(
    new Set(
      [
        "Excel",
        "CRM",
        "Salesforce",
        "HubSpot",
        "Customer service",
        "Scheduling",
        "Project management",
        "Communication",
        "Reporting",
        "Data entry",
        "Microsoft Office",
        "Google Workspace",
        "SQL",
        "Python",
        "JavaScript",
        "TypeScript",
        "React",
        "Next.js",
        "Ruby",
        "Rails",
        "Redis",
        "GraphQL",
        "AWS",
        "Leadership",
        "Administration",
        "Documentation",
      ].filter((skill) =>
        new RegExp(`\\b${skill.replace(".", "\\.")}\\b`, "i").test(text)
      )
    )
  );

  return {
    companyName: titleCase(company.replace(/^company:\s*/i, "")),
    jobTitle: titleCase(title.replace(/^position:\s*/i, "")),
    location,
    workArrangement: workArrangement as WorkArrangement,
    salaryRange: salary,
    contactEmail,
    jobUrl,
    skills,
    jobDescription: text,
    applicationInstructions: extractLine(text, [
      "apply",
      "application instructions",
      "how to apply",
    ]),
  };
}

function commonWords(a: string, b: string) {
  const ignore = new Set([
    "the",
    "and",
    "for",
    "with",
    "you",
    "our",
    "this",
    "that",
    "will",
    "are",
    "from",
  ]);
  const words = new Set(
    a.split(/\W+/).filter((word) => word.length > 3 && !ignore.has(word))
  );
  return b.split(/\W+/).filter((word) => words.has(word)).length;
}

function scoreApplication(app: JobApplication, entries: ExperienceEntry[]) {
  const profileText = entries
    .map(
      (entry) => `${entry.title} ${entry.technologies} ${entry.tags} ${entry.details}`
    )
    .join(" ")
    .toLowerCase();
  const jobText = `${app.jobDescription} ${app.skills.join(" ")}`.toLowerCase();
  const skills = app.skills.length
    ? app.skills
    : ["communication", "organization", "follow-up"];
  const matches = skills.filter((skill) => profileText.includes(skill.toLowerCase()));
  const textBonus =
    jobText && profileText
      ? Math.min(18, Math.floor(commonWords(jobText, profileText) / 5))
      : 0;
  const score = Math.min(98, Math.max(48, 58 + matches.length * 8 + textBonus));
  return {
    matchScore: score,
    matchReason:
      matches.length > 0
        ? `Strong overlap around ${matches.slice(0, 4).join(", ")}. Emphasize those points in the resume and cover letter.`
        : "Some transferable strengths are likely here, but the experience log needs more specific examples to make the match obvious.",
    projectRecommendations: entries
      .filter(
        (entry) =>
          entry.entryType === "project" ||
          matches.some((skill) => entry.details.toLowerCase().includes(skill.toLowerCase()))
      )
      .slice(0, 3)
      .map((entry) => entry.title),
    experienceTailoring: entries.slice(0, 3).map(
      (entry) =>
        `For ${entry.title}, highlight ${entry.technologies || "clear outcomes"} and connect it to ${app.jobTitle || "this role"}.`
    ),
    matchingSkills: matches,
    missingSkills: skills.filter((skill) => !matches.includes(skill)),
  };
}

function generateCoverLetter(
  app: JobApplication,
  profile: Profile,
  entries: ExperienceEntry[]
) {
  const name = profile.name || "Your Name";
  const proof = entries[0];
  const project = entries.find((entry) => entry.entryType === "project");
  return [
    `Dear Hiring Team,`,
    ``,
    `I am excited to apply for the ${app.jobTitle || "role"} at ${app.companyName || "your organization"}. The role stood out because it calls for someone who can combine organized execution, clear communication, and practical follow-through.`,
    ``,
    proof
      ? `In my experience with ${proof.title}${proof.organization ? ` at ${proof.organization}` : ""}, I ${proof.details.charAt(0).toLowerCase()}${proof.details.slice(1)}`
      : `My background has helped me build steady habits around communication, prioritization, documentation, and helping teams keep momentum.`,
    project
      ? ` I would also bring the same approach I used on ${project.title}, where the work centered on ${project.details.charAt(0).toLowerCase()}${project.details.slice(1)}`
      : ``,
    ``,
    app.skills.length
      ? `This position mentions ${app.skills.slice(0, 5).join(", ")}, and I would be ready to connect those needs to real examples from my work.`
      : `I would welcome the chance to connect the needs of this role to specific examples from my work.`,
    ` I am especially drawn to roles where being dependable, thoughtful, and easy to work with makes the team stronger.`,
    ``,
    `Thank you for your time and consideration. I would be glad to talk about how my experience could support ${app.companyName || "your team"}.`,
    ``,
    `Sincerely,`,
    name,
    profile.email || profile.phone
      ? [profile.email, profile.phone].filter(Boolean).join(" | ")
      : "",
  ]
    .filter((line, index, arr) => line !== "" || arr[index - 1] !== "")
    .join("\n");
}

export default function Home() {
  const [applications, setApplications] = useState<JobApplication[]>([]);
  const [entries, setEntries] = useState<ExperienceEntry[]>(SAMPLE_ENTRIES);
  const [profile, setProfile] = useState<Profile>(EMPTY_PROFILE);
  const [openRouterApiKey, setOpenRouterApiKey] = useState("");
  const [activeView, setActiveView] = useState<View>("dashboard");
  const [statusFilter, setStatusFilter] = useState<Status | null>(null);
  const [selectedId, setSelectedId] = useState<string>("");
  const [draft, setDraft] = useState<JobApplication>(blankApplication());
  const [pasteText, setPasteText] = useState("");
  const [entryDraft, setEntryDraft] = useState<ExperienceEntry>(blankEntry());
  const [hydrated, setHydrated] = useState(false);
  const [aiBusy, setAiBusy] = useState<AiBusyState>(null);
  const [flash, setFlash] = useState<{ type: "notice" | "alert"; message: string } | null>(
    null
  );

  useEffect(() => {
    const saved = typeof window !== "undefined" ? localStorage.getItem(STORAGE_KEY) : null;
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        setApplications(parsed.applications || []);
        setEntries(parsed.entries?.length ? parsed.entries : SAMPLE_ENTRIES);
        setProfile(parsed.profile || EMPTY_PROFILE);
      } catch {
        localStorage.removeItem(STORAGE_KEY);
      }
    }
    setOpenRouterApiKey(localStorage.getItem(API_KEY_STORAGE_KEY) || "");
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ applications, entries, profile })
    );
  }, [applications, entries, profile, hydrated]);

  useEffect(() => {
    if (!hydrated) return;
    if (openRouterApiKey.trim()) {
      localStorage.setItem(API_KEY_STORAGE_KEY, openRouterApiKey.trim());
    } else {
      localStorage.removeItem(API_KEY_STORAGE_KEY);
    }
  }, [openRouterApiKey, hydrated]);

  useEffect(() => {
    if (!flash) return;
    const t = setTimeout(() => setFlash(null), 4000);
    return () => clearTimeout(t);
  }, [flash]);

  const selected = applications.find((app) => app.id === selectedId);

  const filteredApplications = useMemo(() => {
    return applications
      .filter((app) => statusFilter === null || app.status === statusFilter)
      .sort((a, b) => +new Date(b.updatedAt) - +new Date(a.updatedAt));
  }, [applications, statusFilter]);

  const skillsInsight = useMemo(() => {
    const profileText = entries
      .map(
        (entry) =>
          `${entry.title} ${entry.technologies} ${entry.tags} ${entry.details}`
      )
      .join(" ")
      .toLowerCase();
    const totals = new Map<string, { total: number; matching: number; missing: number }>();
    applications.forEach((app) => {
      app.skills.forEach((skill) => {
        const key = skill;
        const has = profileText.includes(skill.toLowerCase());
        const cur = totals.get(key) || { total: 0, matching: 0, missing: 0 };
        cur.total += 1;
        if (has) cur.matching += 1;
        else cur.missing += 1;
        totals.set(key, cur);
      });
    });
    return Array.from(totals.entries())
      .map(([name, v]) => ({ name, ...v }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 25);
  }, [applications, entries]);

  function showFlash(type: "notice" | "alert", message: string) {
    setFlash({ type, message });
  }

  async function callAi<T>(action: Exclude<AiBusyState, null>, payload: Record<string, unknown>) {
    setAiBusy(action);
    try {
      const response = await fetch("/api/ai", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action,
          openRouterApiKey: openRouterApiKey.trim(),
          ...payload,
        }),
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || "AI request failed.");
      }
      return data as T;
    } finally {
      setAiBusy(null);
    }
  }

  function navigate(view: View) {
    setActiveView(view);
    if (typeof window !== "undefined") {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }

  function saveApplication(
    app: JobApplication,
    isNew: boolean,
    options: { rescore?: boolean } = {}
  ) {
    const now = new Date().toISOString();
    const scored = options.rescore === false ? {} : scoreApplication({ ...app, updatedAt: now }, entries);
    const next = { ...app, ...scored, updatedAt: now };
    setApplications((current) => {
      return isNew || !current.some((item) => item.id === app.id)
        ? [next, ...current.filter((item) => item.id !== app.id)]
        : current.map((item) => (item.id === app.id ? next : item));
    });
    setSelectedId(app.id);
    setDraft(blankApplication());
    setPasteText("");
    showFlash("notice", isNew ? "Application created." : "Application updated.");
    navigate("show");
  }

  function submitNewManual(event: FormEvent) {
    event.preventDefault();
    if (!draft.companyName.trim() || !draft.jobTitle.trim()) {
      showFlash("alert", "Company and job title are required.");
      return;
    }
    saveApplication(draft, true);
  }

  function submitEdit(event: FormEvent) {
    event.preventDefault();
    if (!draft.companyName.trim() || !draft.jobTitle.trim()) {
      showFlash("alert", "Company and job title are required.");
      return;
    }
    saveApplication(draft, false);
  }

  async function submitPaste(event: FormEvent) {
    event.preventDefault();
    if (!pasteText.trim()) {
      showFlash("alert", "Paste a job posting first.");
      return;
    }
    try {
      const parsed = await callAi<{
        company_name?: string | null;
        job_title?: string | null;
        location?: string | null;
        work_arrangement?: WorkArrangement | null;
        salary_range?: string | null;
        job_description?: string | null;
        skills?: string[] | null;
        contact_email?: string | null;
        application_instructions?: string | null;
        job_url?: string | null;
      }>("parse", { rawContent: pasteText });
      const app: JobApplication = {
        ...blankApplication(),
        companyName: parsed.company_name || "Untitled company",
        jobTitle: parsed.job_title || "Untitled role",
        location: parsed.location || "",
        workArrangement: parsed.work_arrangement || "",
        salaryRange: parsed.salary_range || "",
        jobDescription: parsed.job_description || pasteText,
        skills: Array.isArray(parsed.skills) ? parsed.skills.filter(Boolean) : [],
        contactEmail: parsed.contact_email || "",
        applicationInstructions: parsed.application_instructions || "",
        jobUrl: parsed.job_url || "",
      };
      saveApplication(app, true);
      await regenerateInsights(app, { quiet: true });
    } catch (error) {
      const fallback = parseJobPosting(pasteText);
      const app: JobApplication = { ...blankApplication(), ...fallback };
      if (!app.companyName.trim()) app.companyName = "Untitled company";
      if (!app.jobTitle.trim()) app.jobTitle = "Untitled role";
      saveApplication(app, true);
      showFlash(
        "alert",
        error instanceof Error
          ? `AI parsing failed, so I saved a basic draft instead: ${error.message}`
          : "AI parsing failed, so I saved a basic draft instead."
      );
    }
  }

  function updateStatus(app: JobApplication, status: Status) {
    setApplications((current) =>
      current.map((item) =>
        item.id === app.id
          ? {
              ...item,
              status,
              appliedAt:
                status === "applied" && !item.appliedAt
                  ? new Date().toISOString().slice(0, 10)
                  : item.appliedAt,
              updatedAt: new Date().toISOString(),
            }
          : item
      )
    );
  }

  function deleteApplication(app: JobApplication) {
    if (!confirm("Are you sure?")) return;
    setApplications((current) => current.filter((item) => item.id !== app.id));
    setSelectedId("");
    showFlash("notice", "Application deleted.");
    navigate("dashboard");
  }

  async function regenerateInsights(
    app: JobApplication,
    options: { quiet?: boolean } = {}
  ) {
    try {
      const insights = await callAi<{
        match_score?: number;
        match_reason?: string;
        project_recommendations?: string[];
        experience_tailoring?: string[];
      }>("insights", { application: app, profile, entries });
      setApplications((current) =>
        current.map((item) =>
          item.id === app.id
            ? {
                ...item,
                matchScore: Number(insights.match_score || 0),
                matchReason: insights.match_reason || "",
                projectRecommendations: Array.isArray(insights.project_recommendations)
                  ? insights.project_recommendations
                  : [],
                experienceTailoring: Array.isArray(insights.experience_tailoring)
                  ? insights.experience_tailoring
                  : [],
                updatedAt: new Date().toISOString(),
              }
            : item
        )
      );
      if (!options.quiet) showFlash("notice", "AI insights regenerated.");
    } catch (error) {
      const scored = scoreApplication({ ...app, updatedAt: new Date().toISOString() }, entries);
      setApplications((current) =>
        current.map((item) =>
          item.id === app.id
            ? { ...item, ...scored, updatedAt: new Date().toISOString() }
            : item
        )
      );
      showFlash(
        "alert",
        error instanceof Error
          ? `AI insights failed, so I used a basic local estimate: ${error.message}`
          : "AI insights failed, so I used a basic local estimate."
      );
    }
  }

  async function regenerateCoverLetter(app: JobApplication) {
    try {
      const result = await callAi<{ cover_letter?: string }>("cover_letter", {
        application: app,
        profile,
        entries,
      });
      setApplications((current) =>
        current.map((item) =>
          item.id === app.id
            ? {
                ...item,
                coverLetter: result.cover_letter || "",
                updatedAt: new Date().toISOString(),
              }
            : item
        )
      );
      showFlash("notice", "AI cover letter generated.");
    } catch (error) {
      setApplications((current) =>
        current.map((item) =>
          item.id === app.id
            ? {
                ...item,
                coverLetter: generateCoverLetter(item, profile, entries),
                updatedAt: new Date().toISOString(),
              }
            : item
        )
      );
      showFlash(
        "alert",
        error instanceof Error
          ? `AI cover letter failed, so I used a basic local draft: ${error.message}`
          : "AI cover letter failed, so I used a basic local draft."
      );
    }
  }

  function downloadCoverLetter(app: JobApplication) {
    const text = app.coverLetter || generateCoverLetter(app, profile, entries);
    const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${app.companyName || "company"}-${app.jobTitle || "cover-letter"}.txt`
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-");
    link.click();
    URL.revokeObjectURL(url);
  }

  function addEntry(event: FormEvent) {
    event.preventDefault();
    if (!entryDraft.title.trim() || !entryDraft.details.trim()) {
      showFlash("alert", "Title and details are required.");
      return;
    }
    setEntries((current) => [{ ...entryDraft, id: makeId() }, ...current]);
    setEntryDraft(blankEntry());
    showFlash("notice", "Entry added.");
  }

  function updateEntry(entry: ExperienceEntry) {
    setEntries((current) =>
      current.map((item) => (item.id === entry.id ? entry : item))
    );
    showFlash("notice", "Entry saved.");
  }

  function deleteEntry(entry: ExperienceEntry) {
    if (!confirm("Delete this entry?")) return;
    setEntries((current) => current.filter((item) => item.id !== entry.id));
    showFlash("notice", "Entry deleted.");
  }

  function openShow(app: JobApplication) {
    setSelectedId(app.id);
    navigate("show");
  }

  function openEdit(app: JobApplication) {
    setSelectedId(app.id);
    setDraft({ ...app });
    navigate("edit");
  }

  function openNewManual() {
    setDraft(blankApplication());
    navigate("new-manual");
  }

  function openNewPaste() {
    setPasteText("");
    setDraft(blankApplication());
    navigate("new-paste");
  }

  return (
    <>
      <Header
        onLogo={() => {
          setStatusFilter(null);
          navigate("dashboard");
        }}
        onSkills={() => navigate("skills")}
        onExperience={() => navigate("experience")}
        onSettings={() => navigate("settings")}
        onNew={openNewPaste}
      />

      <main className="max-w-7xl mx-auto mt-24 px-5 pb-16">
        {flash && (
          <div
            className={`mb-4 px-4 py-3 rounded-lg text-sm ${
              flash.type === "notice"
                ? "bg-emerald-50 border border-emerald-200 text-emerald-800"
                : "bg-red-50 border border-red-200 text-red-800"
            }`}
          >
            {flash.message}
          </div>
        )}

        {activeView === "dashboard" && (
          <DashboardView
            applications={filteredApplications}
            statusFilter={statusFilter}
            setStatusFilter={setStatusFilter}
            onPaste={openNewPaste}
            onOpen={openShow}
          />
        )}

        {activeView === "new-paste" && (
          <NewFromPasteView
            value={pasteText}
            setValue={setPasteText}
            onSubmit={submitPaste}
            onManual={openNewManual}
            onCancel={() => navigate("dashboard")}
            busy={aiBusy === "parse"}
          />
        )}

        {activeView === "new-manual" && (
          <ApplicationFormView
            draft={draft}
            setDraft={setDraft}
            onSubmit={submitNewManual}
            onCancel={() => navigate("dashboard")}
            onPasteInstead={openNewPaste}
            mode="new"
          />
        )}

        {activeView === "edit" && selected && (
          <ApplicationFormView
            draft={draft}
            setDraft={setDraft}
            onSubmit={submitEdit}
            onCancel={() => navigate("show")}
            mode="edit"
          />
        )}

        {activeView === "show" && selected && (
          <ShowView
            app={selected}
            onBack={() => navigate("dashboard")}
            onEdit={() => openEdit(selected)}
            onDelete={() => deleteApplication(selected)}
            onStatus={(status) => updateStatus(selected, status)}
            onRegenerate={() => regenerateInsights(selected)}
            onCoverLetter={() => regenerateCoverLetter(selected)}
            onDownloadCoverLetter={() => downloadCoverLetter(selected)}
            entries={entries}
            aiBusy={aiBusy}
          />
        )}

        {activeView === "skills" && (
          <SkillsInsightsView
            applications={applications}
            skills={skillsInsight}
          />
        )}

        {activeView === "experience" && (
          <ExperienceLogView
            entries={entries}
            onManage={() => navigate("experience-edit")}
          />
        )}

        {activeView === "experience-edit" && (
          <ExperienceEditView
            entries={entries}
            entryDraft={entryDraft}
            setEntryDraft={setEntryDraft}
            onAdd={addEntry}
            onSave={updateEntry}
            onDelete={deleteEntry}
            onBack={() => navigate("experience")}
          />
        )}

        {activeView === "settings" && (
          <SettingsView
            profile={profile}
            setProfile={setProfile}
            openRouterApiKey={openRouterApiKey}
            setOpenRouterApiKey={setOpenRouterApiKey}
            onClear={() => {
              if (
                confirm("Clear all saved job tracker data from this browser?")
              ) {
                setApplications([]);
                setEntries(SAMPLE_ENTRIES);
                setProfile(EMPTY_PROFILE);
                setOpenRouterApiKey("");
                showFlash("notice", "Local data cleared.");
              }
            }}
          />
        )}
      </main>
    </>
  );
}

function Header({
  onLogo,
  onSkills,
  onExperience,
  onSettings,
  onNew,
}: {
  onLogo: () => void;
  onSkills: () => void;
  onExperience: () => void;
  onSettings: () => void;
  onNew: () => void;
}) {
  return (
    <header className="fixed top-0 left-0 right-0 h-14 bg-white border-b border-gh-border z-50 shadow-sm">
      <nav className="max-w-7xl mx-auto px-5 h-full flex items-center justify-between">
        <button
          onClick={onLogo}
          className="flex items-center gap-2 text-gray-900 font-bold text-lg hover:text-gh-green transition-colors"
        >
          <svg
            className="w-5 h-5 text-gh-green"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fillRule="evenodd"
              d="M6 6V5a3 3 0 013-3h2a3 3 0 013 3v1h2a2 2 0 012 2v3.57A22.952 22.952 0 0110 13a22.95 22.95 0 01-8-1.43V8a2 2 0 012-2h2zm2-1a1 1 0 011-1h2a1 1 0 011 1v1H8V5zm1 5a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1z"
              clipRule="evenodd"
            />
            <path d="M2 13.692V16a2 2 0 002 2h12a2 2 0 002-2v-2.308A24.974 24.974 0 0110 15c-2.796 0-5.487-.46-8-1.308z" />
          </svg>
          Job Tracker
        </button>

        <div className="flex items-center gap-5">
          <button
            onClick={onSkills}
            className="text-gray-500 hover:text-gray-900 text-sm font-medium transition-colors"
          >
            Skills Insights
          </button>
          <button
            onClick={onExperience}
            className="text-gray-500 hover:text-gray-900 text-sm font-medium transition-colors"
          >
            Experience Log
          </button>
          <button
            onClick={onSettings}
            className="text-gray-500 hover:text-gray-900 text-sm font-medium transition-colors"
          >
            Settings
          </button>

          <button
            onClick={onNew}
            className="bg-gh-green hover:bg-gh-green-light text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors"
          >
            New Application
          </button>
        </div>
      </nav>
    </header>
  );
}

function DashboardView({
  applications,
  statusFilter,
  setStatusFilter,
  onPaste,
  onOpen,
}: {
  applications: JobApplication[];
  statusFilter: Status | null;
  setStatusFilter: (s: Status | null) => void;
  onPaste: () => void;
  onOpen: (app: JobApplication) => void;
}) {
  return (
    <div className="w-full">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Applications</h1>
        <div className="flex items-center gap-3">
          <button
            onClick={onPaste}
            className="bg-gh-green hover:bg-gh-green-light text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors inline-flex items-center gap-2"
          >
            <svg
              className="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 4v16m8-8H4"
              />
            </svg>
            New Application
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2 mb-6">
        <button
          onClick={() => setStatusFilter(null)}
          className={`text-xs font-semibold px-3 py-1.5 rounded-full border transition-colors ${
            statusFilter === null
              ? "bg-gh-green border-gh-green text-white"
              : "border-gray-300 text-gray-600 hover:bg-gray-100"
          }`}
        >
          All
        </button>
        {STATUSES.map((status) => (
          <button
            key={status}
            onClick={() => setStatusFilter(status)}
            className={`text-xs font-semibold px-3 py-1.5 rounded-full border transition-colors ${
              statusFilter === status
                ? "bg-gh-green border-gh-green text-white"
                : "border-gray-300 text-gray-600 hover:bg-gray-100"
            }`}
          >
            {capitalize(status)}
          </button>
        ))}
      </div>

      {applications.length > 0 ? (
        <div className="overflow-x-auto rounded-xl border border-gh-border bg-white shadow-sm">
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-500 uppercase text-[11px] tracking-wider border-b border-gh-border">
              <tr>
                <th className="px-4 py-3 font-semibold">Company</th>
                <th className="px-4 py-3 font-semibold">Title</th>
                <th className="px-4 py-3 font-semibold">Match</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Location</th>
                <th className="px-4 py-3 font-semibold">Applied</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gh-border">
              {applications.map((app) => {
                const score = app.matchScore;
                const scoreColor =
                  score >= 80
                    ? "text-emerald-600"
                    : score >= 60
                      ? "text-blue-600"
                      : score >= 40
                        ? "text-amber-600"
                        : "text-red-600";
                return (
                  <tr
                    key={app.id}
                    className="hover:bg-gray-50 transition-colors group"
                  >
                    <td className="px-4 py-3">
                      <button
                        onClick={() => onOpen(app)}
                        className="text-gray-900 font-medium hover:text-gh-green transition-colors text-left"
                      >
                        {app.companyName}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{app.jobTitle}</td>
                    <td className="px-4 py-3">
                      {score ? (
                        <span className={`${scoreColor} text-xs font-semibold`}>
                          {score}%
                        </span>
                      ) : (
                        <span className="text-gray-400 text-xs">--</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`${STATUS_BADGE[app.status]} text-xs font-medium px-2.5 py-0.5 rounded-full`}
                      >
                        {capitalize(app.status)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-500">
                      {app.location || "--"}
                    </td>
                    <td className="px-4 py-3 text-gray-500">
                      {formatDate(app.appliedAt)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="text-center py-16 text-gray-500">
          <svg
            className="w-12 h-12 text-gray-300 mx-auto mb-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1}
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
            />
          </svg>
          {statusFilter ? (
            <>
              <p className="mb-4">No {statusFilter} applications.</p>
              <button
                onClick={() => setStatusFilter(null)}
                className="text-gh-green hover:text-gh-green-light transition-colors text-sm font-medium"
              >
                View all applications
              </button>
            </>
          ) : (
            <>
              <p className="mb-4">No applications yet.</p>
              <button
                onClick={onPaste}
                className="text-gh-green hover:text-gh-green-light transition-colors text-sm font-medium"
              >
                Paste your first job posting
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
}

function NewFromPasteView({
  value,
  setValue,
  onSubmit,
  onManual,
  onCancel,
  busy,
}: {
  value: string;
  setValue: (s: string) => void;
  onSubmit: (e: FormEvent) => void;
  onManual: () => void;
  onCancel: () => void;
  busy: boolean;
}) {
  return (
    <div className="max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Paste & Parse</h1>
        <button
          onClick={onManual}
          className="text-gh-green hover:text-gh-green-light text-sm font-medium transition-colors"
        >
          Or fill in manually
        </button>
      </div>

      <p className="text-gray-500 mb-6">
        Paste a job posting below and we&apos;ll extract the details automatically.
      </p>

      <form onSubmit={onSubmit} className="space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Job Posting
          </label>
          <textarea
            rows={15}
            required
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder="Paste the full job posting here..."
            className="w-full bg-white border border-gray-300 rounded-lg px-3 py-2 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-gh-green/30 focus:border-gh-green"
          />
        </div>

        <div className="flex items-center gap-4">
          <button
            type="submit"
            disabled={busy}
            className="bg-gh-green hover:bg-gh-green-light disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-semibold px-6 py-2 rounded-lg transition-colors cursor-pointer"
          >
            {busy ? "Parsing with AI..." : "Parse & Create"}
          </button>
          <button
            type="button"
            onClick={onCancel}
            className="text-gray-500 hover:text-gray-700 transition-colors"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}

function ApplicationFormView({
  draft,
  setDraft,
  onSubmit,
  onCancel,
  onPasteInstead,
  mode,
}: {
  draft: JobApplication;
  setDraft: (d: JobApplication) => void;
  onSubmit: (e: FormEvent) => void;
  onCancel: () => void;
  onPasteInstead?: () => void;
  mode: "new" | "edit";
}) {
  const inputClass =
    "w-full bg-white border border-gray-300 rounded-lg px-3 py-2 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-gh-green/30 focus:border-gh-green";
  const labelClass = "block text-sm font-medium text-gray-700 mb-1";

  return (
    <div className="max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">
          {mode === "new" ? "New Application" : "Edit Application"}
        </h1>
        {mode === "new" && onPasteInstead && (
          <button
            onClick={onPasteInstead}
            className="text-gh-green hover:text-gh-green-light text-sm font-medium transition-colors"
          >
            Or paste &amp; parse a job posting
          </button>
        )}
      </div>

      <form onSubmit={onSubmit} className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className={labelClass}>Company name</label>
            <input
              required
              value={draft.companyName}
              onChange={(e) => setDraft({ ...draft, companyName: e.target.value })}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Job title</label>
            <input
              required
              value={draft.jobTitle}
              onChange={(e) => setDraft({ ...draft, jobTitle: e.target.value })}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Location</label>
            <input
              value={draft.location}
              onChange={(e) => setDraft({ ...draft, location: e.target.value })}
              placeholder="e.g., San Francisco, CA"
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Work arrangement</label>
            <select
              value={draft.workArrangement}
              onChange={(e) =>
                setDraft({
                  ...draft,
                  workArrangement: e.target.value as WorkArrangement,
                })
              }
              className={inputClass}
            >
              <option value="">Select...</option>
              <option value="remote">Remote</option>
              <option value="hybrid">Hybrid</option>
              <option value="onsite">Onsite</option>
            </select>
          </div>
          <div>
            <label className={labelClass}>Salary range</label>
            <input
              value={draft.salaryRange}
              onChange={(e) => setDraft({ ...draft, salaryRange: e.target.value })}
              placeholder="e.g., $120k - $150k"
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Job URL</label>
            <input
              type="url"
              value={draft.jobUrl}
              onChange={(e) => setDraft({ ...draft, jobUrl: e.target.value })}
              placeholder="https://..."
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Contact email</label>
            <input
              type="email"
              value={draft.contactEmail}
              onChange={(e) => setDraft({ ...draft, contactEmail: e.target.value })}
              placeholder="recruiter@company.com"
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Status</label>
            <select
              value={draft.status}
              onChange={(e) => setDraft({ ...draft, status: e.target.value as Status })}
              className={inputClass}
            >
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {capitalize(s)}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div>
          <label className={labelClass}>Skills (comma separated)</label>
          <input
            value={draft.skills.join(", ")}
            onChange={(e) =>
              setDraft({
                ...draft,
                skills: e.target.value
                  .split(",")
                  .map((s) => s.trim())
                  .filter(Boolean),
              })
            }
            placeholder="React, TypeScript, GraphQL"
            className={inputClass}
          />
        </div>

        <div>
          <label className={labelClass}>Job description</label>
          <textarea
            rows={6}
            value={draft.jobDescription}
            onChange={(e) =>
              setDraft({ ...draft, jobDescription: e.target.value })
            }
            placeholder="Paste or type the job description..."
            className={inputClass}
          />
        </div>

        <div>
          <label className={labelClass}>Application instructions</label>
          <textarea
            rows={3}
            value={draft.applicationInstructions}
            onChange={(e) =>
              setDraft({ ...draft, applicationInstructions: e.target.value })
            }
            placeholder="How to apply, special requirements..."
            className={inputClass}
          />
        </div>

        <div>
          <label className={labelClass}>Notes</label>
          <textarea
            rows={3}
            value={draft.notes}
            onChange={(e) => setDraft({ ...draft, notes: e.target.value })}
            placeholder="Your personal notes about this application..."
            className={inputClass}
          />
        </div>

        <div className="flex items-center gap-4">
          <button
            type="submit"
            className="bg-gh-green hover:bg-gh-green-light text-white font-semibold px-6 py-2 rounded-lg transition-colors cursor-pointer"
          >
            {mode === "new" ? "Create application" : "Save changes"}
          </button>
          <button
            type="button"
            onClick={onCancel}
            className="text-gray-500 hover:text-gray-700 transition-colors"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}

function ShowView({
  app,
  onBack,
  onEdit,
  onDelete,
  onStatus,
  onRegenerate,
  onCoverLetter,
  onDownloadCoverLetter,
  entries,
  aiBusy,
}: {
  app: JobApplication;
  onBack: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onStatus: (s: Status) => void;
  onRegenerate: () => void;
  onCoverLetter: () => void;
  onDownloadCoverLetter: () => void;
  entries: ExperienceEntry[];
  aiBusy: AiBusyState;
}) {
  const [activeTab, setActiveTab] = useState<
    "cover-letter" | "resume" | "projects" | "details"
  >("cover-letter");

  const profileText = entries
    .map((entry) => `${entry.title} ${entry.technologies} ${entry.tags} ${entry.details}`)
    .join(" ")
    .toLowerCase();

  function skillStatus(skill: string): "matching" | "missing" | "neutral" {
    if (!profileText) return "neutral";
    return profileText.includes(skill.toLowerCase()) ? "matching" : "missing";
  }

  const matchingCount = app.skills.filter((s) => skillStatus(s) === "matching").length;
  const missingCount = app.skills.filter((s) => skillStatus(s) === "missing").length;

  const score = app.matchScore;
  const scoreColor =
    score >= 80
      ? "text-emerald-600 border-emerald-200 bg-emerald-50"
      : score >= 60
        ? "text-blue-600 border-blue-200 bg-blue-50"
        : score >= 40
          ? "text-amber-600 border-amber-200 bg-amber-50"
          : "text-red-600 border-red-200 bg-red-50";

  const tabBase =
    "pb-3 text-sm font-medium border-b-2 transition-colors cursor-pointer";
  const tabClass = (active: boolean) =>
    `${tabBase} ${
      active
        ? "border-gh-green text-gh-green"
        : "border-transparent text-gray-500 hover:text-gray-700"
    }`;

  return (
    <div className="max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={onBack}
          className="text-gray-500 hover:text-gray-700 text-sm font-medium transition-colors"
        >
          ← Applications
        </button>
        <div className="flex items-center gap-2">
          <button
            onClick={onRegenerate}
            disabled={aiBusy === "insights"}
            className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-white border border-gray-300 hover:bg-gray-50 disabled:bg-gray-100 disabled:text-gray-400 disabled:cursor-not-allowed text-gray-700 transition-colors inline-flex items-center gap-1.5 shadow-sm"
          >
            <svg
              className="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
              />
            </svg>
            {aiBusy === "insights" ? "Running AI..." : "Regenerate"}
          </button>
          <button
            onClick={onEdit}
            className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-white border border-gray-300 hover:bg-gray-50 text-gray-700 transition-colors shadow-sm"
          >
            Edit
          </button>
          <button
            onClick={onDelete}
            className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-white border border-red-300 hover:bg-red-50 text-red-600 transition-colors shadow-sm"
          >
            Delete
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div className="lg:col-span-4 space-y-4">
          <div className="lg:sticky lg:top-20 space-y-4">
            <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
              <div className="flex items-start justify-between gap-3 mb-3">
                <div className="min-w-0">
                  <h1 className="text-xl font-bold text-gray-900 leading-tight">
                    {app.jobTitle}
                  </h1>
                  <p className="text-gray-500 mt-1">{app.companyName}</p>
                </div>
                {score > 0 && (
                  <div
                    className={`${scoreColor} border rounded-xl px-3 py-2 text-center shrink-0`}
                  >
                    <div className="text-2xl font-bold leading-none">{score}</div>
                    <div className="text-[10px] uppercase tracking-wider mt-0.5 opacity-70">
                      match
                    </div>
                  </div>
                )}
              </div>

              {app.matchReason && (
                <p className="text-xs text-gray-500 leading-relaxed mb-4">
                  {app.matchReason}
                </p>
              )}

              <div className="flex flex-wrap gap-1.5">
                {STATUSES.map((status) => {
                  const isCurrent = status === app.status;
                  return (
                    <button
                      key={status}
                      onClick={() => onStatus(status)}
                      className={`text-[11px] font-semibold px-2.5 py-1 rounded-full border transition-colors cursor-pointer ${
                        isCurrent
                          ? "bg-gh-green border-gh-green text-white"
                          : "border-gray-300 text-gray-500 hover:bg-gray-100 hover:text-gray-700"
                      }`}
                    >
                      {capitalize(status)}
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
              <dl className="space-y-3 text-sm">
                {app.location && (
                  <div className="flex items-center gap-2.5">
                    <svg
                      className="w-4 h-4 text-gray-400 shrink-0"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={1.5}
                        d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                      />
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={1.5}
                        d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                    </svg>
                    <span className="text-gray-700">{app.location}</span>
                    {app.workArrangement && (
                      <span className="text-[10px] uppercase tracking-wider text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded">
                        {app.workArrangement}
                      </span>
                    )}
                  </div>
                )}
                {app.salaryRange && (
                  <div className="flex items-center gap-2.5">
                    <svg
                      className="w-4 h-4 text-gray-400 shrink-0"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={1.5}
                        d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    <span className="text-gray-700">{app.salaryRange}</span>
                  </div>
                )}
                {app.contactEmail && (
                  <div className="flex items-center gap-2.5">
                    <svg
                      className="w-4 h-4 text-gray-400 shrink-0"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={1.5}
                        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                      />
                    </svg>
                    <a
                      href={`mailto:${app.contactEmail}`}
                      className="text-gray-700 truncate"
                    >
                      {app.contactEmail}
                    </a>
                  </div>
                )}
                {app.jobUrl && (
                  <div className="flex items-center gap-2.5">
                    <svg
                      className="w-4 h-4 text-gray-400 shrink-0"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={1.5}
                        d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                      />
                    </svg>
                    <a
                      href={app.jobUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="text-gh-green hover:text-gh-green-light transition-colors font-medium"
                    >
                      View posting →
                    </a>
                  </div>
                )}
              </dl>

              <div className="border-t border-gh-border mt-4 pt-4">
                <dl className="grid grid-cols-2 gap-3 text-xs">
                  <div>
                    <dt className="text-gray-400">Saved</dt>
                    <dd className="text-gray-600 mt-0.5">
                      {formatDate(app.createdAt, {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                      })}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-gray-400">Applied</dt>
                    <dd className="text-gray-600 mt-0.5">
                      {app.appliedAt
                        ? formatDate(app.appliedAt, {
                            month: "short",
                            day: "numeric",
                            year: "numeric",
                          })
                        : "--"}
                    </dd>
                  </div>
                </dl>
              </div>
            </div>

            {app.skills.length > 0 && (
              <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
                <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
                  Skills Match
                </h3>
                <div className="flex flex-wrap gap-1.5">
                  {app.skills.map((skill) => {
                    const s = skillStatus(skill);
                    const pill =
                      s === "matching"
                        ? "bg-emerald-50 text-emerald-700 border-emerald-200"
                        : s === "missing"
                          ? "bg-red-50 text-red-600 border-red-200"
                          : "bg-gray-50 text-gray-600 border-gray-200";
                    return (
                      <span
                        key={skill}
                        className={`text-[11px] font-medium px-2 py-0.5 rounded-full border ${pill}`}
                      >
                        {skill}
                      </span>
                    );
                  })}
                </div>
                {(matchingCount > 0 || missingCount > 0) && (
                  <div className="flex items-center gap-3 mt-3 text-xs">
                    <span className="flex items-center gap-1 text-emerald-600">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                      {matchingCount} matched
                    </span>
                    <span className="flex items-center gap-1 text-red-500">
                      <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
                      {missingCount} gaps
                    </span>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="lg:col-span-8">
          <div className="border-b border-gh-border mb-6">
            <nav className="flex gap-6 -mb-px">
              <button
                onClick={() => setActiveTab("cover-letter")}
                className={tabClass(activeTab === "cover-letter")}
              >
                Cover Letter
              </button>
              <button
                onClick={() => setActiveTab("resume")}
                className={tabClass(activeTab === "resume")}
              >
                Experience Writer
              </button>
              <button
                onClick={() => setActiveTab("projects")}
                className={tabClass(activeTab === "projects")}
              >
                Projects
              </button>
              <button
                onClick={() => setActiveTab("details")}
                className={tabClass(activeTab === "details")}
              >
                Job Details
              </button>
            </nav>
          </div>

          {activeTab === "cover-letter" && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-gray-900">
                  Cover Letter
                </h2>
                <div className="flex items-center gap-2">
                  {app.coverLetter && (
                    <>
                      <button
                        onClick={() => {
                          navigator.clipboard.writeText(app.coverLetter).catch(
                            () => undefined
                          );
                        }}
                        className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-white border border-gray-300 hover:bg-gray-50 text-gray-700 transition-colors shadow-sm"
                      >
                        Copy
                      </button>
                      <button
                        onClick={onDownloadCoverLetter}
                        className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-white border border-gray-300 hover:bg-gray-50 text-gray-700 transition-colors shadow-sm inline-flex items-center gap-1.5"
                      >
                        <svg
                          className="w-3.5 h-3.5"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                          />
                        </svg>
                        Download
                      </button>
                      <button
                        onClick={onCoverLetter}
                        disabled={aiBusy === "cover_letter"}
                        className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-gh-green hover:bg-gh-green-light disabled:bg-gray-300 disabled:cursor-not-allowed text-white transition-colors shadow-sm"
                      >
                        {aiBusy === "cover_letter" ? "Writing..." : "Regenerate"}
                      </button>
                    </>
                  )}
                </div>
              </div>

              {app.coverLetter ? (
                <div className="bg-white border border-gh-border rounded-xl p-6 shadow-sm">
                  <div className="text-gray-700 text-sm leading-relaxed whitespace-pre-wrap">
                    {app.coverLetter}
                  </div>
                </div>
              ) : (
                <div className="bg-white border border-gh-border rounded-xl p-12 text-center shadow-sm">
                  <p className="text-gray-500 text-sm mb-3">
                    Cover letters are generated manually.
                  </p>
                  <button
                    onClick={onCoverLetter}
                    disabled={aiBusy === "cover_letter"}
                    className="text-xs font-semibold px-4 py-2 rounded-lg bg-gh-green hover:bg-gh-green-light disabled:bg-gray-300 disabled:cursor-not-allowed text-white transition-colors"
                  >
                    {aiBusy === "cover_letter" ? "Writing with AI..." : "Generate Cover Letter"}
                  </button>
                </div>
              )}
            </div>
          )}

          {activeTab === "resume" && (
            <div>
              <h2 className="text-lg font-semibold text-gray-900 mb-4">
                Experience Writer
              </h2>
              {app.experienceTailoring.length > 0 ? (
                <div className="space-y-4">
                  <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Tailoring Notes
                  </h3>
                  {app.experienceTailoring.map((note, idx) => (
                    <div
                      key={idx}
                      className="bg-white border border-gh-border rounded-xl p-5 shadow-sm"
                    >
                      <p className="text-sm text-gray-700 leading-relaxed">{note}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="bg-white border border-gh-border rounded-xl p-12 text-center shadow-sm">
                  <p className="text-gray-400 text-sm">
                    No experience rewrites yet. Click &quot;Regenerate&quot; to
                    generate tailored notes.
                  </p>
                </div>
              )}
            </div>
          )}

          {activeTab === "projects" && (
            <div>
              <h2 className="text-lg font-semibold text-gray-900 mb-4">
                Project Strategy
              </h2>
              {app.projectRecommendations.length > 0 ? (
                <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
                  <div className="flex items-center gap-2 mb-4">
                    <span className="w-2 h-2 rounded-full bg-emerald-500" />
                    <h3 className="text-sm font-semibold text-gray-900">
                      Feature These
                    </h3>
                  </div>
                  <ul className="space-y-3">
                    {app.projectRecommendations.map((project) => (
                      <li key={project} className="text-sm text-emerald-700 font-medium">
                        {project}
                      </li>
                    ))}
                  </ul>
                </div>
              ) : (
                <div className="bg-white border border-gh-border rounded-xl p-12 text-center shadow-sm">
                  <p className="text-gray-400 text-sm">
                    No project recommendations yet. Click &quot;Regenerate&quot; to
                    get advice.
                  </p>
                </div>
              )}
            </div>
          )}

          {activeTab === "details" && (
            <div>
              <h2 className="text-lg font-semibold text-gray-900 mb-4">
                Job Details
              </h2>
              <div className="space-y-4">
                {app.jobDescription && (
                  <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
                    <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
                      Description
                    </h3>
                    <div className="text-gray-700 text-sm leading-relaxed whitespace-pre-wrap">
                      {app.jobDescription}
                    </div>
                  </div>
                )}
                {app.applicationInstructions && (
                  <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
                    <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
                      How to Apply
                    </h3>
                    <div className="text-gray-700 text-sm leading-relaxed whitespace-pre-wrap">
                      {app.applicationInstructions}
                    </div>
                  </div>
                )}
                {app.notes && (
                  <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
                    <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
                      Notes
                    </h3>
                    <div className="text-gray-700 text-sm leading-relaxed whitespace-pre-wrap">
                      {app.notes}
                    </div>
                  </div>
                )}
                {!app.jobDescription &&
                  !app.applicationInstructions &&
                  !app.notes && (
                    <div className="bg-white border border-gh-border rounded-xl p-12 text-center shadow-sm">
                      <p className="text-gray-400 text-sm">
                        No details available.{" "}
                        <button
                          onClick={onEdit}
                          className="text-gh-green hover:text-gh-green-light font-medium"
                        >
                          Edit this application
                        </button>{" "}
                        to add them.
                      </p>
                    </div>
                  )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function SkillsInsightsView({
  applications,
  skills,
}: {
  applications: JobApplication[];
  skills: { name: string; total: number; matching: number; missing: number }[];
}) {
  const total = applications.length;
  const analyzed = applications.filter((app) => app.skills.length > 0).length;
  const biggestGap = skills
    .filter((s) => s.missing > 0)
    .sort((a, b) => b.missing - a.missing)[0];
  const max = skills[0]?.total || 0;

  return (
    <div className="w-full">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Skills Insights</h1>
        <p className="text-sm text-gray-500 mt-1">
          Most requested skills across your job applications — focus on closing the
          gaps.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
            Applications Analyzed
          </p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{analyzed}</p>
          <p className="text-xs text-gray-400 mt-0.5">of {total} total</p>
        </div>
        <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
            Unique Skills Tracked
          </p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{skills.length}</p>
        </div>
        <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
            Biggest Gap
          </p>
          {biggestGap ? (
            <>
              <p className="text-2xl font-bold text-red-600 mt-1">
                {biggestGap.name}
              </p>
              <p className="text-xs text-gray-400 mt-0.5">
                missing in {biggestGap.missing} applications
              </p>
            </>
          ) : (
            <>
              <p className="text-2xl font-bold text-emerald-600 mt-1">None!</p>
              <p className="text-xs text-gray-400 mt-0.5">
                You match all analyzed skills
              </p>
            </>
          )}
        </div>
      </div>

      {skills.length > 0 ? (
        <>
          <div className="bg-white border border-gh-border rounded-xl shadow-sm overflow-hidden">
            <div className="px-5 py-4 border-b border-gh-border">
              <h2 className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
                Most Requested Skills
              </h2>
            </div>

            <div className="divide-y divide-gh-border">
              {skills.map((skill, index) => (
                <div
                  key={skill.name}
                  className="px-5 py-3.5 flex items-center gap-4"
                >
                  <span className="text-xs font-semibold text-gray-400 w-6 text-right shrink-0">
                    {index + 1}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="text-sm font-semibold text-gray-900 truncate">
                        {skill.name}
                      </span>
                      <span className="text-xs text-gray-400 shrink-0 ml-2">
                        {skill.total} {skill.total === 1 ? "posting" : "postings"}
                      </span>
                    </div>
                    <div className="w-full bg-gray-100 rounded-full h-2">
                      <div
                        className="bg-gh-green rounded-full h-2 transition-all"
                        style={{
                          width: `${Math.round((skill.total / max) * 100)}%`,
                        }}
                      />
                    </div>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    {skill.matching > 0 && (
                      <span className="flex items-center gap-1 text-xs font-medium text-emerald-600 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                        {skill.matching}
                      </span>
                    )}
                    {skill.missing > 0 && (
                      <span className="flex items-center gap-1 text-xs font-medium text-red-600 bg-red-50 border border-red-200 px-2 py-0.5 rounded-full">
                        <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
                        {skill.missing}
                      </span>
                    )}
                    {skill.matching === 0 && skill.missing === 0 && (
                      <span className="text-xs text-gray-400">--</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-4 mt-4 text-xs text-gray-400">
            <span className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
              You have this skill
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
              Skill gap identified
            </span>
          </div>
        </>
      ) : (
        <div className="text-center py-16 text-gray-500">
          <svg
            className="w-12 h-12 text-gray-300 mx-auto mb-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1}
              d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
            />
          </svg>
          <p className="mb-2 font-medium text-gray-600">No skills data yet</p>
          <p className="text-sm">
            Add job applications with skills to see insights here.
          </p>
        </div>
      )}
    </div>
  );
}

function ExperienceLogView({
  entries,
  onManage,
}: {
  entries: ExperienceEntry[];
  onManage: () => void;
}) {
  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Experience Log</h1>
        <button
          onClick={onManage}
          className="bg-gh-green hover:bg-gh-green-light text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors"
        >
          Manage Entries
        </button>
      </div>

      <p className="text-gray-500 text-sm mb-6">
        Use this as a master log of everything you&apos;ve built. The tracker picks
        relevant evidence per job application.
      </p>

      {entries.length > 0 ? (
        <div className="space-y-4">
          {entries.map((entry) => (
            <div
              key={entry.id}
              className="bg-white border border-gh-border rounded-xl p-5 shadow-sm"
            >
              <div className="flex items-center justify-between gap-4 mb-2">
                <div>
                  <p className="text-xs uppercase tracking-wider text-gray-400 font-semibold">
                    {entry.entryType}
                  </p>
                  <h2 className="text-base font-semibold text-gray-900">
                    {entry.title}
                  </h2>
                </div>
                <p className="text-xs text-gray-400">
                  {entry.dateRange || "Date range not set"}
                </p>
              </div>

              <p className="text-sm text-gray-500 mb-2">
                {[entry.organization, entry.location].filter(Boolean).join(" · ")}
              </p>
              {entry.technologies && (
                <p className="text-xs text-gh-green font-medium mb-2">
                  {entry.technologies}
                </p>
              )}
              <div className="text-sm text-gray-700 whitespace-pre-wrap">
                {entry.details}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white border border-gh-border rounded-xl p-8 text-center shadow-sm">
          <p className="text-gray-500 mb-3">No experience entries yet.</p>
          <p className="text-gray-400 text-sm mb-5">
            Add experience and projects in your log to power tailored output.
          </p>
          <button
            onClick={onManage}
            className="bg-gh-green hover:bg-gh-green-light text-white font-semibold px-6 py-2 rounded-lg transition-colors"
          >
            Add First Entry
          </button>
        </div>
      )}
    </div>
  );
}

function ExperienceEditView({
  entries,
  entryDraft,
  setEntryDraft,
  onAdd,
  onSave,
  onDelete,
  onBack,
}: {
  entries: ExperienceEntry[];
  entryDraft: ExperienceEntry;
  setEntryDraft: (e: ExperienceEntry) => void;
  onAdd: (e: FormEvent) => void;
  onSave: (e: ExperienceEntry) => void;
  onDelete: (e: ExperienceEntry) => void;
  onBack: () => void;
}) {
  const inputClass =
    "w-full bg-white border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-gh-green focus:ring-1 focus:ring-gh-green/30";

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Manage Experience Log</h1>
        <p className="text-sm text-gray-500 mt-1">
          Store raw evidence here. Include extra work that may not appear on your
          final resume.
        </p>
      </div>

      <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Add Entry</h2>
        <form onSubmit={onAdd} className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-gray-700 font-medium mb-1">
                Entry type
              </label>
              <select
                value={entryDraft.entryType}
                onChange={(e) =>
                  setEntryDraft({
                    ...entryDraft,
                    entryType: e.target.value as "experience" | "project",
                  })
                }
                className={inputClass}
              >
                <option value="experience">Experience</option>
                <option value="project">Project</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-gray-700 font-medium mb-1">
                Title
              </label>
              <input
                required
                value={entryDraft.title}
                onChange={(e) =>
                  setEntryDraft({ ...entryDraft, title: e.target.value })
                }
                placeholder="Full Stack Developer Intern"
                className={inputClass}
              />
            </div>
            <div>
              <label className="block text-sm text-gray-700 font-medium mb-1">
                Organization
              </label>
              <input
                value={entryDraft.organization}
                onChange={(e) =>
                  setEntryDraft({ ...entryDraft, organization: e.target.value })
                }
                placeholder="Leanpub"
                className={inputClass}
              />
            </div>
            <div>
              <label className="block text-sm text-gray-700 font-medium mb-1">
                Date range
              </label>
              <input
                value={entryDraft.dateRange}
                onChange={(e) =>
                  setEntryDraft({ ...entryDraft, dateRange: e.target.value })
                }
                placeholder="May 2025 - Dec 2025"
                className={inputClass}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-gray-700 font-medium mb-1">
                Location
              </label>
              <input
                value={entryDraft.location}
                onChange={(e) =>
                  setEntryDraft({ ...entryDraft, location: e.target.value })
                }
                placeholder="Victoria, BC"
                className={inputClass}
              />
            </div>
            <div>
              <label className="block text-sm text-gray-700 font-medium mb-1">
                Technologies
              </label>
              <input
                value={entryDraft.technologies}
                onChange={(e) =>
                  setEntryDraft({ ...entryDraft, technologies: e.target.value })
                }
                placeholder="Ruby on Rails, Redis, GraphQL, AWS S3"
                className={inputClass}
              />
            </div>
          </div>

          <div>
            <label className="block text-sm text-gray-700 font-medium mb-1">
              Tags
            </label>
            <input
              value={entryDraft.tags}
              onChange={(e) =>
                setEntryDraft({ ...entryDraft, tags: e.target.value })
              }
              placeholder="testing, backend, api, infrastructure"
              className={inputClass}
            />
          </div>

          <div>
            <label className="block text-sm text-gray-700 font-medium mb-1">
              Evidence / Raw notes
            </label>
            <textarea
              required
              rows={8}
              value={entryDraft.details}
              onChange={(e) =>
                setEntryDraft({ ...entryDraft, details: e.target.value })
              }
              placeholder={`- What you built\n- Why it mattered\n- Metrics\n- Edge cases / debugging work\n- Anything that might be relevant to future jobs`}
              className={`${inputClass} whitespace-pre-wrap`}
            />
          </div>

          <div className="flex gap-3">
            <button
              type="submit"
              className="bg-gh-green hover:bg-gh-green-light text-white text-sm font-semibold px-4 py-2 rounded-lg transition-colors cursor-pointer"
            >
              Add Entry
            </button>
            <button
              type="button"
              onClick={onBack}
              className="text-gray-500 hover:text-gray-700 text-sm px-3 py-2 transition-colors"
            >
              Back
            </button>
          </div>
        </form>
      </div>

      <div className="space-y-4">
        {entries.map((entry) => (
          <EntryEditCard
            key={entry.id}
            entry={entry}
            onSave={onSave}
            onDelete={onDelete}
          />
        ))}
      </div>
    </div>
  );
}

function EntryEditCard({
  entry,
  onSave,
  onDelete,
}: {
  entry: ExperienceEntry;
  onSave: (e: ExperienceEntry) => void;
  onDelete: (e: ExperienceEntry) => void;
}) {
  const [local, setLocal] = useState(entry);
  useEffect(() => setLocal(entry), [entry]);

  const inputClass =
    "bg-white border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-gh-green focus:ring-1 focus:ring-gh-green/30";

  return (
    <div className="bg-white border border-gh-border rounded-xl p-5 shadow-sm">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSave(local);
        }}
        className="space-y-3"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <select
            value={local.entryType}
            onChange={(e) =>
              setLocal({
                ...local,
                entryType: e.target.value as "experience" | "project",
              })
            }
            className={inputClass}
          >
            <option value="experience">Experience</option>
            <option value="project">Project</option>
          </select>
          <input
            value={local.title}
            onChange={(e) => setLocal({ ...local, title: e.target.value })}
            className={inputClass}
          />
          <input
            value={local.organization}
            onChange={(e) =>
              setLocal({ ...local, organization: e.target.value })
            }
            placeholder="Organization"
            className={inputClass}
          />
          <input
            value={local.dateRange}
            onChange={(e) => setLocal({ ...local, dateRange: e.target.value })}
            placeholder="Date range"
            className={inputClass}
          />
          <input
            value={local.location}
            onChange={(e) => setLocal({ ...local, location: e.target.value })}
            placeholder="Location"
            className={inputClass}
          />
          <input
            value={local.technologies}
            onChange={(e) =>
              setLocal({ ...local, technologies: e.target.value })
            }
            placeholder="Technologies"
            className={inputClass}
          />
        </div>
        <input
          value={local.tags}
          onChange={(e) => setLocal({ ...local, tags: e.target.value })}
          placeholder="Tags"
          className={`w-full ${inputClass}`}
        />
        <textarea
          value={local.details}
          onChange={(e) => setLocal({ ...local, details: e.target.value })}
          rows={6}
          className={`w-full ${inputClass} whitespace-pre-wrap`}
        />
        <div className="flex items-center gap-3">
          <button
            type="submit"
            className="bg-gray-100 hover:bg-gray-200 text-gray-700 text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors cursor-pointer border border-gray-300"
          >
            Save
          </button>
          <button
            type="button"
            onClick={() => onDelete(entry)}
            className="bg-white hover:bg-red-50 border border-red-300 text-red-600 text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors"
          >
            Delete
          </button>
        </div>
      </form>
    </div>
  );
}

function SettingsView({
  profile,
  setProfile,
  openRouterApiKey,
  setOpenRouterApiKey,
  onClear,
}: {
  profile: Profile;
  setProfile: (p: Profile) => void;
  openRouterApiKey: string;
  setOpenRouterApiKey: (key: string) => void;
  onClear: () => void;
}) {
  const inputClass =
    "w-full bg-white border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-gh-green focus:ring-1 focus:ring-gh-green/30";

  const fields: { key: keyof Profile; label: string; placeholder: string }[] = [
    { key: "name", label: "Full Name", placeholder: "Sam McClenaghan" },
    { key: "phone", label: "Phone", placeholder: "780-221-1327" },
    { key: "email", label: "Email", placeholder: "sam@aream.ca" },
    { key: "linkedin", label: "LinkedIn", placeholder: "linkedin.com/in/sam-mcclenaghan" },
    { key: "site", label: "Website / GitHub", placeholder: "github.com/sammcclenaghan" },
  ];

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-8">Settings</h1>

      <div className="bg-white border border-gh-border rounded-xl p-6 mb-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900 mb-1">
          Cover Letter Profile
        </h2>
        <p className="text-xs text-gray-500 mb-5">
          Personal details used in the cover letter header.
        </p>

        <div className="space-y-4">
          {fields.map(({ key, label, placeholder }) => (
            <div key={key}>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {label}
              </label>
              <input
                value={profile[key]}
                onChange={(e) =>
                  setProfile({ ...profile, [key]: e.target.value })
                }
                placeholder={placeholder}
                className={inputClass}
              />
            </div>
          ))}
        </div>
      </div>

      <div className="bg-white border border-gh-border rounded-xl p-6 mb-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900 mb-1">
          AI Provider
        </h2>
        <p className="text-xs text-gray-500 mb-5">
          Add an OpenRouter API key so paste parsing, insights, and cover letters
          use real AI. The key is saved only in this browser.
        </p>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          OpenRouter API key
        </label>
        <input
          type="password"
          value={openRouterApiKey}
          onChange={(e) => setOpenRouterApiKey(e.target.value)}
          placeholder="sk-or-v1-..."
          className={inputClass}
        />
      </div>

      <div className="bg-white border border-gh-border rounded-xl p-6 mb-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900 mb-1">
          Local Storage
        </h2>
        <p className="text-xs text-gray-500 mb-5">
          This version saves everything in this browser on this device. It is easy
          to deploy, private by default, and does not need a database.
        </p>
        <button
          onClick={onClear}
          className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-white border border-red-300 hover:bg-red-50 text-red-600 transition-colors"
        >
          Clear local data
        </button>
      </div>
    </div>
  );
}

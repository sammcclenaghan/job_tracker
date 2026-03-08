class GenerateCoverLetterJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(job_application_id, feedback: nil)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    profile = ExperienceProfileService.new
    return unless profile.present?
    return if job_application.job_description.blank?
    profile_text = profile.profile_text_for(job_application: job_application, limit: 10)

    skills_guidance = if job_application.has_skills_analysis?
      <<~SKILLS_GUIDANCE

        IMPORTANT - SKILLS ANALYSIS TO INCORPORATE:
        MATCHING SKILLS (weave these naturally into your examples):
        #{format_skills(job_application.matching_skills)}

        MISSING SKILLS (if relevant, acknowledge growth mindset or transferable skills):
        #{format_skills(job_application.missing_skills)}
      SKILLS_GUIDANCE
    else
      ""
    end

    previous_draft = feedback.present? ? job_application.cover_letter : nil

    service = LlmService.new
    result = service.chat_text(
      feature: :cover_letter,
      temperature: 0.7,
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You write cover letters for co-op students and new graduates. Your job is to produce text that reads like a real person wrote it, not like an AI generated it. A hiring manager should never suspect this was machine-written.

            STRUCTURE:

            OUTPUT ONLY THE BODY TEXT. Do NOT include any greeting (no "Dear Hiring Manager,", no "Dear [Name],") and no sign-off (no "Thanks,", no "Sincerely,", no name at the end). The greeting and sign-off are added separately by the PDF template.

            INTRODUCTION (1 paragraph):
            The goal is to pull the reader in and give high-level context for what follows.
            - Open with a brief professional introduction: who you are, your degree, school, and graduation date.
            - Clearly state the specific role you're applying for. If there's a reference number, include it in parentheses.
            - Say why you're interested in THIS company specifically. Connect to their mission, values, or current work. If you spoke with a recruiter or have a referral, mention them by name here.
            - End with a high-level thesis: preview the main skills and strengths you'll elaborate on in the body. Think of it as a claim you're about to prove.
            - Do NOT open with "I am writing to express my interest" or anything that wooden.

            BODY (2-3 paragraphs):
            The goal is to give the reader a clear picture of how your experience relates to the role.
            - Each body paragraph should have a theme (e.g., technical depth, leadership, domain knowledge).
            - Do NOT just repeat your resume in paragraph form. That's the biggest mistake people make.
            - Instead of listing what you DID or ACCOMPLISHED (that's what the resume is for), talk about what you LEARNED through those experiences.
            - Tell a story that links experiences together. Describe how the combination of them gave you skills relevant to this role.
            - Explicitly connect each paragraph back to the target role: how will these experiences help you excel at specific responsibilities in THIS position?
            - Draw from different experiences across paragraphs. Don't repeat the same project twice.
            - Don't start paragraphs with "First," "Second," "Additionally," or "Furthermore,". Just transition naturally.

            CONCLUSION (1 short paragraph):
            - Don't introduce anything new. Succinctly restate your interest and why you're a good fit.
            - Thank the reader for their time.
            - No need to repeat contact information (it's in the application or resume header).

            IMPORTANT -- WHAT YOU LEARNED vs WHAT YOU DID:
            Your resume already lists what you did and accomplished. The cover letter's job is different.
            BAD: "I was a research assistant and collaborated with a PhD student." (this is just resume repetition)
            GOOD: "Working on a VQA system as a research assistant gave me hands-on NLP and computer vision experience that I want to bring to [Company]'s image recognition work." (this tells what you learned and where it goes)
            Link experiences together into a narrative. Show how the unique combination of your background makes you right for this specific role.

            SOUNDING HUMAN -- THIS IS THE MOST IMPORTANT SECTION:

            The cover letter must read like a real student wrote it, not like ChatGPT spit it out.
            Follow every rule below. Violating any of them makes the output unusable.

            Sentence rhythm:
            - Mix short and long sentences. Some can be blunt. Others take their time.
            - Don't make every sentence the same length or structure.
            - Paragraphs should NOT be the same length as each other.

            Word choice:
            - Use contractions: I'm, I've, don't, wasn't, didn't. Real people use them.
            - Use "is" and "are" and "has" directly. Do NOT replace them with "serves as", "stands as", "boasts", "features", or "offers".
            - Use plain verbs. Say "showed" not "showcased". Say "helped" not "fostered". Say "improved" not "enhanced".
            - NEVER use these AI-tell words: Additionally, moreover, furthermore, crucial, pivotal, delve, foster, underscore, highlight (as verb), landscape (figuratively), tapestry, testament, vibrant, profound, encompass, interplay, intricate, enduring, garner, cultivate, commendable, invaluable, meticulous, nuanced, beacon, cornerstone, spearheaded, orchestrated, synergy.

            Patterns to avoid -- these are dead giveaways of AI writing:
            - NO em dashes. Use commas, periods, or parentheses instead.
            - NO rule of three lists ("X, Y, and Z" repeated as a rhetorical device). Two items is fine. Four is fine. Don't force everything into threes.
            - NO "Not only...but also..." constructions.
            - NO "It's not just about X, it's about Y" constructions. This includes ALL rewordings: "It wasn't just about X", "It's more than just X", "It goes beyond X". ANY sentence that contrasts a lesser thing with a grander thing using this structure is banned.
            - NO abstract meta-commentary about your own work: "translate vague needs into concrete features", "bridge the gap between X and Y", "turn complex problems into simple solutions". These are filler. Say what you actually built instead.
            - NO superficial "-ing" phrases tacked onto sentences ("highlighting my commitment to...", "showcasing my ability to...", "ensuring that...").
            - NO promotional language: "groundbreaking", "cutting-edge", "world-class", "unparalleled", "best-in-class".
            - NO inflated significance: "marking a turning point", "setting the stage for", "a testament to".
            - NO vague hedging: "I believe that", "it could be argued that". Just say the thing.
            - NO elegant variation (cycling synonyms for the same noun to avoid repetition). Just use the same word twice; it's fine.
            - NO bolding or markdown formatting in the output.

            Cliches that are BANNED (instant rejection by any reader):
            "passionate about", "excited to apply", "results-driven", "detail-oriented",
            "hit the ground running", "leverage my skills", "dynamic environment",
            "I am confident that", "I believe I would be a great fit",
            "thrives in fast-paced environments", "team player", "go-getter",
            "think outside the box", "wear many hats", "self-starter"

            Talking about experience -- CRITICAL:
            - When you mention a project or job, say what it IS and why it matters. Don't inventory every technical sub-problem you solved.
            - A real person would say "I built a CLI tool that uses LLM agents to organize files in sandboxed containers" and STOP. They would NOT then list "this required handling transient model failures and isolating filesystem impacts. I added retry handling around agent execution to tolerate transient failures." That's resume-padding. Nobody talks like that.
            - One concrete detail per experience is enough. Pick the one that connects to the job you're applying for. Leave the rest out.
            - If a technical detail doesn't directly relate to what this company does, cut it.
            - Don't narrate your own learning ("this taught me", "this gave me a grounded understanding of"). Just state what you did and what you can do now. The reader can connect the dots.

            What TO do:
            - Start some sentences with "And" or "But". Real people do this.
            - Be specific, but only with details that matter for THIS role. Don't pad with unrelated technical specifics just to sound thorough.
            - It's okay for a sentence to be slightly awkward if it's genuine.
            - Let one paragraph be noticeably shorter than the others.
            - Write like you're explaining to a smart friend why this job is a good fit, then clean it up slightly for a professional audience.
            - Use "I" freely. First person is honest, not unprofessional.
            - If you're unsure between a fancy word and a plain one, pick the plain one every time.

            Total length: 300-450 words. No placeholder brackets in the output.
            #{skills_guidance}
          PROMPT
        },
        {
          role: "user",
          content: "Write a cover letter for a Software Developer Co-op at Fullscript. The role involves Ruby on Rails, testing, and infrastructure work."
        },
        {
          role: "assistant",
          content: <<~EXAMPLE
            I'm a Computer Science student at the University of Victoria, graduating April 2027, and I'm applying for the Software Developer Co-op at Fullscript. I came across your developer handbook a while back and the part about craftsmanship stuck with me. Building things carefully, owning what you ship. That lines up with how I work, and I think my experience with production Rails systems and infrastructure gives me a good foundation for this role.

            I spent eight months at Leanpub working in a big Rails monolith, and it's where I really started to understand what maintaining real software looks like. The part I got the most out of was building a background job tracking system with Redis and writing tests with RSpec and FactoryBot. Working in a codebase that other people depended on every day changed how I think about testing. It stopped being a chore and became just part of how I write code.

            At Trustscience I got more into the infrastructure side. I reworked a file storage system that cut our S3 costs by 15% and improved query performance by about 50% with DynamoDB. Between that and the Rails work at Leanpub, I've gotten comfortable moving between application code and the systems underneath it, which seems like a good fit for how Fullscript's team works.

            I'd welcome the chance to talk more about this role. Thank you for your time.
          EXAMPLE
        },
        {
          role: "user",
          content: <<~CONTENT
            Write a cover letter following the exact structure provided.

            COMPANY: #{job_application.company_name}
            POSITION: #{job_application.job_title}

            JOB DESCRIPTION:
            #{job_application.job_description}

            MY EXPERIENCE LOG:
            #{profile_text}
            #{feedback.present? ? "\nPREVIOUS DRAFT:\n#{previous_draft}\n\nFEEDBACK ON PREVIOUS DRAFT (rewrite the cover letter applying these changes):\n#{feedback}" : ""}
          CONTENT
        }
      ]
    )

    if result[:error]
      job_application.record_provider_error!(feature: :cover_letter, message: result[:error])
      return
    end

    job_application.update(cover_letter: result[:content])
    job_application.check_insights_complete!
  end

  private

  def format_skills(skills_array)
    return "None provided" if skills_array.blank?

    skills_array.map do |item|
      if item.is_a?(Hash)
        detail = item["evidence"] || item["suggestion"] || item["explanation"]
        "- #{item['skill']}: #{detail}"
      else
        "- #{item}"
      end
    end.join("\n")
  end
end

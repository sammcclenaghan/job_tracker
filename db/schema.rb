# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_03_000000) do
  create_table "experience_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_range"
    t.text "details", null: false
    t.string "entry_type", default: "experience", null: false
    t.string "location"
    t.string "organization"
    t.string "tags"
    t.string "technologies"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_type"], name: "index_experience_entries_on_entry_type"
    t.index ["updated_at"], name: "index_experience_entries_on_updated_at"
  end

  create_table "job_applications", force: :cascade do |t|
    t.text "application_instructions"
    t.datetime "applied_at"
    t.string "company_name"
    t.string "contact_email"
    t.text "cover_letter"
    t.datetime "created_at", null: false
    t.json "experience_tailoring"
    t.datetime "followed_up_at"
    t.string "insights_status", default: "pending"
    t.text "job_description"
    t.string "job_title"
    t.string "job_url"
    t.string "location"
    t.integer "match_score"
    t.text "match_score_reasoning"
    t.text "notes"
    t.json "project_recommendations"
    t.text "provider_error"
    t.json "resume_suggestions"
    t.string "salary_range"
    t.text "skills"
    t.text "skills_analysis"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "work_arrangement"
  end

  create_table "resumes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.text "value"
  end
end

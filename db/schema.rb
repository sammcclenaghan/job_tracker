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

ActiveRecord::Schema[8.1].define(version: 2026_01_13_020842) do
  create_table "job_applications", force: :cascade do |t|
    t.text "application_instructions"
    t.datetime "applied_at"
    t.string "company_name"
    t.string "contact_email"
    t.text "cover_letter"
    t.datetime "created_at", null: false
    t.datetime "followed_up_at"
    t.text "job_description"
    t.string "job_title"
    t.string "job_url"
    t.string "location"
    t.text "notes"
    t.string "salary_range"
    t.text "skills"
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

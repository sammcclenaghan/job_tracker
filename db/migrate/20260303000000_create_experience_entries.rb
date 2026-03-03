class CreateExperienceEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :experience_entries do |t|
      t.string :entry_type, null: false, default: "experience"
      t.string :title, null: false
      t.string :organization
      t.string :location
      t.string :date_range
      t.string :technologies
      t.string :tags
      t.text :details, null: false

      t.timestamps
    end

    add_index :experience_entries, :entry_type
    add_index :experience_entries, :updated_at
  end
end

# Seeds the primary database with real data captured from a backup.
#
# Data lives in db/seed_data.sql as `INSERT OR REPLACE` statements, so running
# this multiple times is idempotent (rows are matched by primary key).
#
# Load it with: bin/rails db:seed   (or db:setup, which creates + seeds)

seed_sql = Rails.root.join("db", "seed_data.sql")

if seed_sql.exist?
  ActiveRecord::Base.connection.raw_connection.execute_batch(seed_sql.read)
  puts "Seeded from #{seed_sql.relative_path_from(Rails.root)}: " \
       "#{JobApplication.count} job applications, " \
       "#{ExperienceEntry.count} experience entries, " \
       "#{Resume.count} resumes, #{Setting.count} settings."
else
  puts "No db/seed_data.sql found; nothing to seed."
end

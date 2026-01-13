class CreateResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :resumes do |t|
      t.text :content

      t.timestamps
    end
  end
end

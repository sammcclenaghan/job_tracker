class Resume < ApplicationRecord
  validates :content, presence: true

  def self.current
    first_or_create(content: "")
  end
end

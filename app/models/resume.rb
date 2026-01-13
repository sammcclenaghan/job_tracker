class Resume < ApplicationRecord
  validates :content, presence: true, on: :update

  def self.current
    first || create!(content: "")
  end
end

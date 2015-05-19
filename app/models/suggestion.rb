class Suggestion < ActiveRecord::Base
  extend FriendlyId
  friendly_id :title, use: :slugged

  reverse_geocoded_by :latitude, :longitude
  after_validation :reverse_geocode  # auto-fetch address

  has_many :comments, dependent: :destroy

  #Validations
  validates :title, presence: :true,
                    length: { maximum: 150 }
  validates :category, presence: :true
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true,
                    format: { with: VALID_EMAIL_REGEX }
  validates :comment, presence: :true

  #Methods
  def self.category
    { suggestion: 1, complaint: 2, congratulation: 3, issue: 4 }
  end

  def self.exists?(slug)
    where(slug: slug).present?
  end

  def self.search_filter(category, title, address, distance)
    conditions = "1 = 1 "
    if !title.nil? && !title.blank?
      words = title.split(" ")
      conditions += "AND ("
      words.each_with_index do |word, index|
        conditions += "(upper(title) LIKE upper('%#{word}%'))"
        conditions += " AND " if index != words.size - 1
      end
      conditions += ")"
    end

    suggestions = Suggestion.where(conditions)
    suggestions = suggestions.where(category: category) if !category.blank?
    suggestions = suggestions.order(created_at: :desc)

    if !address.nil? && !address.blank?
      suggestions = suggestions.near(address, distance.to_f, unit: :km).reorder('distance ASC')
    end

    return suggestions
  end

  def self.find_visible_comments(suggestion_id)
    friendly.find(suggestion_id).comments.where(visible: true)
  end

  def find_visible_comments
    self.comments.where(visible: true)
  end

  def number_of_comments
    self.comments.where(visible: true).size
  end

  def has_comments?
    number_of_comments > 0
  end

  def number_of_supporters
    self.comments.where(visible: true, support: true).size
  end

  def email_has_supported_me?(email)
    self.comments.where(email: email, support: true).count > 0
  end

  def should_generate_new_friendly_id?
    title_changed?
  end

  def visible?
    self.visible
  end

  def has_errors?
    self.errors.any?
  end

  def has_geolocation?
    !self.latitude.nil? && !self.longitude.nil?
  end

  def has_image1?
    !self.image1_id.nil?
  end

  def has_image2?
    !self.image2_id.nil?
  end

  def has_images?
    has_image1? || has_image2?
  end

  def votes_in_favour
    self.comments.where(vote: 1, visible: true).size
  end

  def votes_against
    self.comments.where(vote: 3, visible: true).size
  end

  def votes_in_favour_and_against
    votes_in_favour + votes_against
  end

  def has_address?
    !self.reverse_geocode.nil?
  end

  def street
    self.address.split(',').reverse[3..-1].reverse.join(',')
  end

  def postal_code
    self.address.split(',').reverse[2].to_i
  end

  def district
    self.address.split(',').reverse[2][7..-1]
  end

  def comments_email_list
    emails = Set.new
    self.comments.each { |comment| emails.add(comment.email) }
    return emails
  end
end

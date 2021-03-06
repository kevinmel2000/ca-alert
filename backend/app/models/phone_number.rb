class PhoneNumber < ApplicationRecord
  include Swagger::Blocks

  SMS_FROM_NUMBER = '+18282028536'.freeze

  belongs_to :user

  validates :phone_number, presence: true
  validate :phone_number_not_changed

  before_create :setup_pin

  def as_json(options = {})
    options[:except] ||= []
    options[:except] << :pin
    super(options)
  end

  def alert_user(alert)
    if notifications_enabled? && !is_555?
      intro = "New #{alert.hazard.is_emergency? ? 'EMERGENCY ' : ''}Alert from CAlerts!"
      TWILIO_CLIENT.messages.create(
        from: SMS_FROM_NUMBER,
        to: phone_number,
        body: <<-EOM
#{intro}
Title: #{alert.hazard.title}
Message: #{alert.hazard.message}
Address: #{alert.hazard.address}
Category: #{alert.hazard.category}
Link: #{alert.hazard.link}
Phone: #{alert.hazard.phone_number}
EOM
      )
    end
  end

  required_swagger = [:id, :user_id, :phone_number, :pin_created_at, :pin_attempts, :verified, :created_at, :updated_at]
  swagger_schema :PhoneNumber, required: required_swagger do
    property :id do
      key :type, :integer
      key :format, :int64
    end
    property :user_id do
      key :type, :integer
      key :format, :int64
    end
    property :phone_number do
      key :type, :string
    end
    property :pin_created_at do
      key :type, :string
      key :format, 'date-time'
    end
    property :pin_attempts do
      key :type, :integer
    end
    property :verified do
      key :type, :boolean
    end
    property :notifications_enabled do
      key :type, :boolean
    end
    property :created_at do
      key :type, :string
      key :format, 'date-time'
    end
    property :updated_at do
      key :type, :string
      key :format, 'date-time'
    end
  end

  private

  def setup_pin
    self.pin = rand(00_000..99_999).to_s.rjust(5, '0')
    self.pin_attempts = 0
    self.pin_created_at = Time.now.utc

    unless is_555?
      TWILIO_CLIENT.messages.create(
        from: SMS_FROM_NUMBER,
        to: phone_number,
        body: "Your mobile pin for the California alerts system is #{pin}"
      )
    end
  end

  def is_555?
    phone_number =~ /^555/ || phone_number =~ /^\(555\)/ || phone_number =~ /^1\-555/
  end

  def phone_number_not_changed
    if phone_number_changed? && persisted?
      errors.add(:phone_number, 'can\'t be changed')
    end
  end
end

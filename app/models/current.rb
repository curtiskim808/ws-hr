# Current attributes pattern - DHH style for request-scoped context
# Usage: Current.user, Current.brand accessible anywhere in the request cycle
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :brand, :request_id, :user_agent

  # Automatically set brand from user if not explicitly set
  def brand
    super || user&.brand
  end

  # Resets are automatic at the end of each request
  # But you can also call Current.reset to clear manually
end

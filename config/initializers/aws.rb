# AWS SDK Configuration for SNS Notifications
#
# T117 [P2] [US8] Configure AWS SDK SNS with credentials and region
#
# PURPOSE: Initialize AWS SNS client for publishing notification events
# WHY: HR system publishes events to SNS topic, notification service subscribes
# PATTERN: Fire-and-forget - HR system doesn't wait for notification delivery
#
# ENVIRONMENT VARIABLES:
#   AWS_REGION - AWS region where SNS topic is located (default: us-east-1)
#   AWS_ACCESS_KEY_ID - AWS access key for authentication
#   AWS_SECRET_ACCESS_KEY - AWS secret key for authentication
#   NOTIFICATION_SNS_TOPIC_ARN - Full ARN of the SNS topic
#
# USAGE:
#   AwsConfig.sns_client.publish(
#     topic_arn: AwsConfig.sns_topic_arn,
#     message: payload.to_json
#   )
#
# TEST ENVIRONMENT:
#   In test environment, SNS client returns a mock/stub client
#   to prevent actual AWS calls during testing

module AwsConfig
  class << self
    # SNS client instance (lazy-loaded)
    # RETURNS: Aws::SNS::Client configured with credentials
    # CACHING: Memoized for performance
    def sns_client
      @sns_client ||= build_sns_client
    end

    # SNS topic ARN from environment
    # RETURNS: String ARN for the notification topic
    # EXAMPLE: "arn:aws:sns:us-east-1:123456789012:hr-notifications"
    def sns_topic_arn
      ENV.fetch("NOTIFICATION_SNS_TOPIC_ARN", nil)
    end

    # Check if SNS is properly configured
    # RETURNS: Boolean true if all required config is present
    # USE CASE: Skip SNS calls if not configured (local dev without AWS)
    def sns_configured?
      sns_topic_arn.present? && !Rails.env.test?
    end

    # Reset client (useful for testing)
    def reset!
      @sns_client = nil
    end

    private

    def build_sns_client
      return mock_sns_client if Rails.env.test?

      Aws::SNS::Client.new(
        region: ENV.fetch("AWS_REGION", "us-east-1"),
        credentials: aws_credentials
      )
    end

    def aws_credentials
      Aws::Credentials.new(
        ENV.fetch("AWS_ACCESS_KEY_ID", nil),
        ENV.fetch("AWS_SECRET_ACCESS_KEY", nil)
      )
    end

    # Mock SNS client for test environment
    # PURPOSE: Prevent actual AWS calls in tests
    # BEHAVIOR: Returns success response for all publish calls
    def mock_sns_client
      MockSnsClient.new
    end
  end

  # Mock SNS Client for Testing
  # PURPOSE: Provides test double for AWS SNS client
  # WHY: Tests should not make real AWS API calls
  # USAGE: Automatically used in test environment
  class MockSnsClient
    attr_reader :published_messages

    def initialize
      @published_messages = []
    end

    # Mock publish method
    # PARAMS: Same as Aws::SNS::Client#publish
    # RETURNS: Mock response with message_id
    # SIDE EFFECT: Stores message in published_messages for test assertions
    def publish(params)
      @published_messages << params
      OpenStruct.new(message_id: SecureRandom.uuid)
    end

    # Clear published messages (for test cleanup)
    def clear!
      @published_messages.clear
    end
  end
end

module Cloud
  module Azure
    class Configuration < ApplicationRecord
      validate :presence_of_fields
      before_save :encrypt_credentials

      def self.table_name_prefix
        'cloud_azure_'
      end

      private

      def encrypt_credentials
        self.management_certificate = Crypto::Encrypt.cloud_upload_data(management_certificate) if management_certificate_changed?
        self.subscription_id = Crypto::Encrypt.cloud_upload_data(subscription_id) if subscription_id_changed?
      end

      # a new record has no management certificate or subscription set, so we only validate if the user
      # tries to update these fields.
      def presence_of_fields
        if management_certificate || subscription_id
          errors.add(:subscription_id, 'must not be blank') if subscription_id.blank?
          errors.add(:management_certificate, 'must not be blank') if management_certificate.blank?
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: cloud_azure_configurations
#
#  id                     :integer          not null, primary key
#  user_id                :integer          indexed
#  management_certificate :text(65535)
#  subscription_id        :text(65535)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_cloud_azure_configurations_on_user_id  (user_id)
#

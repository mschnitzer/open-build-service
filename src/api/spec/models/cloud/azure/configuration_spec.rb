require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Cloud::Azure::Configuration, type: :model, vcr: true do
  describe 'data encryption' do
    let(:config) { create(:azure_configuration, application_id: 'Hey OBS!', application_key: 'Hey OBS?') }
    let(:secret_key) { OpenSSL::PKey::RSA.new(File.read(Rails.root.join('spec', 'support', 'files', 'cloudupload_secret_key_tests.pem'))) }

    context '#application_id' do
      it { expect(secret_key.private_decrypt(Base64.decode64(config.application_id))).to eq('Hey OBS!') }
    end

    context '#application_key' do
      it { expect(secret_key.private_decrypt(Base64.decode64(config.application_key))).to eq('Hey OBS?') }
    end
  end
end

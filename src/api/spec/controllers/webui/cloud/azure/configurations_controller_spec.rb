require 'rails_helper'

RSpec.describe Webui::Cloud::Azure::ConfigurationsController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'tom') }
  before do
    login(user)
  end

  describe 'GET #show' do
    context 'without Azure configuration' do
      it 'creates an Azure configuration' do
      end
    end

    context 'with Azure configuration' do
    end
  end

  describe 'PUT #update' do
    context 'with valid parameters' do
    end

    context 'with invalid parameters' do
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the configuration' do
    end
  end
end

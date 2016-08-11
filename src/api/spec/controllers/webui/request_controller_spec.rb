require 'rails_helper'

RSpec.describe Webui::RequestController do
  let(:submitter) { create(:confirmed_user, login: 'kugelblitz' ) }
  let(:receiver) { create(:confirmed_user, login: 'titan' ) }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
  let(:bs_request) { create(:bs_request, description: "Please take this", creator: submitter.login) }
  let(:create_submit_request) do
    bs_request.bs_request_actions.delete_all
    create(:bs_request_action_submit, target_project: target_project.name,
                                      target_package: source_package.name,
                                      source_project: source_project.name,
                                      source_package: source_package.name,
                                      bs_request_id: bs_request.id)
  end

  it { is_expected.to use_before_action(:require_login) }
  it { is_expected.to use_before_action(:require_request) }

  describe 'GET show' do
    it 'is successful as nobody' do
      get :show, number: bs_request.number
      expect(response).to have_http_status(:success)
    end

    it 'assigns @bsreq' do
      get :show, number: bs_request.number
      expect(assigns(:bsreq)).to eq(bs_request)
    end

    it 'redirects to root_path if request does not exist' do
      login submitter
      get :show, number: '200000'
      expect(flash[:error]).to eq("Can't find request 200000")
      expect(response).to redirect_to(user_show_path(User.current))
    end

    it 'shows a note if the user is a project maintainer and there is at least one package maintainer' do
      login receiver

      target_package.add_user(receiver, Role.find_by_title!("maintainer"))
      target_package.save

      get :show, number: bs_request.number

      expect(assigns(:is_project_maintainer)).to eq(false)
      expect(assigns(:is_package_maintainer)).to eq(true)
      #puts "output: #{@is_project_maintainer}"
    end
  end
end

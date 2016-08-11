require 'rails_helper'

RSpec.describe Package, vcr: true do
  let(:user_tom) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user_tom.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:services) { package.services }

  context '#save_file' do
    before do
      User.current = user_tom
    end

    it 'calls #addKiwiImport if filename ends with kiwi.txz' do
      Service.any_instance.expects(:addKiwiImport).once
      package.save_file({ filename: 'foo.kiwi.txz' })
    end

    it 'does not call #addKiwiImport if filename ends not with kiwi.txz' do
      Service.any_instance.expects(:addKiwiImport).never
      package.save_file({ filename: 'foo.spec' })
    end
  end

  context '#maintainers' do
    let(:group) { create(:group, title: 'my_test_group') }
    let(:group_bugowner) { create(:group, title: 'senseless_group') }
    let(:user_tom2) { create(:confirmed_user, login: 'tom2') }
    let(:user_tom3) { create(:confirmed_user, login: 'tom3') }
    let(:user_tom4) { create(:confirmed_user, login: 'tom4') }
    let(:user_tom5) { create(:confirmed_user, login: 'tom5') }
    let(:user_bugowner) { create(:confirmed_user, login: 'bugowner') }

    it 'returns an array with user objects to all maintainers for a package' do
      # first of all, we add a user what here who is not a maintainer but a bugowner
      # he/she should not be recognized by package.maintainers
      package.add_user(user_bugowner, Role.find_by_title!("bugowner"))
      package.save

      # we expect to get one user object in an array
      package.add_user(user_tom, Role.find_by_title!("maintainer"))
      package.save

      expect(package.maintainers).to eq([user_tom])

      # we expect the previous user and the following user to be in that array
      package.add_user(user_tom2, Role.find_by_title!("maintainer"))
      package.save

      expect(package.maintainers).to eq([user_tom, user_tom2])
    end

    it 'resolves groups properly' do
      # groups should be resolved and only their assigned users should be in the
      # returning array
      group.add_user(user_tom3)
      group.add_user(user_tom4)

      # add a group to the package what is not a maintainer to make sure it'll
      # be ignored when calling package.maintainers
      group_bugowner.add_user(user_tom5)

      package.add_group(group_bugowner, Role.find_by_title!("bugowner"))
      package.save

      package.add_group(group, Role.find_by_title!("maintainer"))
      package.save

      expect(package.maintainers).to eq([user_tom3, user_tom4])
    end

    it 'makes sure that no user is listed more than one time' do
      group.add_user(user_tom)
      group_bugowner.add_user(user_tom)

      package.add_group(group, Role.find_by_title!("maintainer"))
      package.add_group(group_bugowner, Role.find_by_title!("maintainer"))
      package.add_user(user_tom, Role.find_by_title!("maintainer"))

      package.save

      expect(package.maintainers).to eq([user_tom])
    end

    it 'returns users and the users of resolved groups' do
      group.add_user(user_tom)
      group_bugowner.add_user(user_tom2)

      package.add_group(group, Role.find_by_title!("maintainer"))
      package.add_group(group_bugowner, Role.find_by_title!("maintainer"))
      package.add_user(user_tom3, Role.find_by_title!("maintainer"))

      package.save

      expect(package.maintainers).to contain_exactly(user_tom, user_tom2, user_tom3)
    end
  end
end

require "rails_helper"
require 'rantly/rspec_extensions'
# WARNING: If you need to make a Backend call uncomment the following line
# CONFIG['global_write_through'] = true

RSpec.describe Project, vcr: true do
  let!(:project) { create(:project, name: 'openSUSE_41') }
  let(:remote_project) { create(:remote_project, name: "openSUSE.org") }
  let(:package) { create(:package, project: project) }
  let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
  let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }

  describe "validations" do
    it {
      is_expected.to validate_inclusion_of(:kind).
        in_array(["standard", "maintenance", "maintenance_incident", "maintenance_release"])
    }
    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_length_of(:title).is_at_most(250) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { should_not allow_value("_foo").for(:name) }
    it { should_not allow_value("foo::bar").for(:name) }
    it { should_not allow_value("ends_with_:").for(:name) }
    it { should allow_value("fOO:+-").for(:name) }
  end

  describe ".image_templates" do
    let!(:attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }

    it { expect(Project.image_templates).to eq([leap_project]) }
  end

  describe "#store" do
    before do
      allow(project).to receive(:save!).and_return(true)
      allow(project).to receive(:write_to_backend).and_return(true)
      project.commit_opts = { comment: 'the comment' }
    end

    context "without commit_opts parameter" do
      it "does not overwrite the commit_opts" do
        project.store
        expect(project.commit_opts).to eq({ comment: 'the comment' })
      end
    end

    context "with commit_opts parameter" do
      it "does overwrite the commit_opts" do
        project.store({ comment: 'a new comment'})
        expect(project.commit_opts).to eq({ comment: 'a new comment' })
      end
    end
  end

  describe "#has_distribution" do
    context "remote distribution" do
      let(:remote_distribution) { create(:repository, name: "snapshot", remote_project_name: "openSUSE:Factory", project: remote_project) }
      let(:other_remote_distribution) { create(:repository, name: "standard", remote_project_name: "openSUSE:Leap:42.1", project: remote_project) }
      let(:repository) { create(:repository, name: "openSUSE_Tumbleweed", project: project) }
      let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: remote_distribution.id, position: 1)}

      it { expect(project.has_distribution("openSUSE.org:openSUSE:Factory", "snapshot")).to be(true) }
      it { expect(project.has_distribution("openSUSE.org:openSUSE:Leap:42.1", "standard")).to be(false) }
    end

    context "local distribution" do
      context "with linked distribution" do
        let(:distribution) { create(:project, name: "BaseDistro2.0") }
        let(:distribution_repository) { create(:repository, name: "BaseDistro2_repo", project: distribution) }
        let(:repository) { create(:repository, name: "Base_repo2", project: project) }
        let!(:path_element) { create(:path_element, parent_id: repository.id, repository_id: distribution_repository.id, position: 1)}

        it { expect(project.has_distribution("BaseDistro2.0", "BaseDistro2_repo")).to be(true) }
      end

      context "with not linked distribution" do
        let(:not_linked_distribution) { create(:project, name: "BaseDistro") }
        let!(:not_linked_distribution_repository) { create(:repository, name: "BaseDistro_repo", project: not_linked_distribution) }

        it { expect(project.has_distribution("BaseDistro", "BaseDistro_repo")).to be(false) }
      end

      context "with linked distribution but wrong query" do
        let(:other_distribution) { create(:project, name: "BaseDistro3.0") }
        let!(:other_distribution_repository) { create(:repository, name: "BaseDistro3_repo", project: other_distribution) }
        let(:other_repository) { create(:repository, name: "Base_repo3", project: project) }
        let!(:path_element) { create(:path_element, parent_id: other_repository.id, repository_id: other_distribution_repository.id, position: 1)}
        it { expect(project.has_distribution("BaseDistro3.0", "standard")).to be(false) }
        it { expect(project.has_distribution("BaseDistro4.0", "BaseDistro3_repo")).to be(false) }
      end
    end
  end

  describe '#image_template?' do
    let!(:image_templates_attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }
    let(:tumbleweed_project) { create(:project, name: 'openSUSE_Tumbleweed') }

    it { expect(leap_project.image_template?).to be(true) }
    it { expect(tumbleweed_project.image_template?).to be(false) }
  end

  describe '#branch_remote_repositories' do
    let(:branch_remote_repositories) { project.branch_remote_repositories("#{remote_project}:#{project}") }

    before do
      logout
      allow(ProjectMetaFile).to receive(:new).and_return(remote_meta_xml)
    end

    context "normal project" do
      let!(:repository) { create(:repository, name: 'xUbuntu_14.04', project: project) }
      let(:remote_meta_xml) {
        <<-XML_DATA
          <project name="home:mschnitzer">
            <title>Cool Title</title>
            <description>Cool Description</description>
            <repository name="xUbuntu_14.04">
              <path project="Ubuntu:14.04" repository="universe"/>
              <arch>i586</arch>
              <arch>x86_64</arch>
            </repository>
            <repository name="openSUSE_42.2">
              <path project="openSUSE:Leap:42.2:Update" repository="standard"/>
              <path project="openSUSE:Leap:42.2:Update2" repository="standard"/>
              <arch>x86_64</arch>
            </repository>
          </project>
        XML_DATA
      }
      let(:local_xml_meta) {
        <<-XML_DATA
          <project name="#{project}">
            <title>#{project.title}</title>
            <description/>
            <repository name="xUbuntu_14.04">
            </repository>
            <repository name="openSUSE_42.2">
              <path project="#{remote_project.name}:#{project}" repository="openSUSE_42.2"/>
              <arch>x86_64</arch>
            </repository>
          </project>
        XML_DATA
      }
      let(:expected_xml) { Nokogiri::XML(local_xml_meta) }

      before do
        branch_remote_repositories
        project.reload
      end

      context 'keeps original repository' do
        let(:old_repository) { project.repositories.first }

        it { expect(old_repository).to eq(repository) }
        it { expect(old_repository.architectures).to be_empty }
        it { expect(old_repository.path_elements).to be_empty }
      end

      context 'adds new reposity' do
        let(:new_repository) { project.repositories.second }
        let(:path_element) { new_repository.path_elements.first.link }

        it { expect(new_repository.name).to eq("openSUSE_42.2") }
        it { expect(new_repository.architectures.first.name).to eq("x86_64") }
        it 'with correct path link' do
          expect(path_element.name).to eq("openSUSE_42.2")
          expect(path_element.remote_project_name).to eq(project.name)
        end
      end
    end

    context "kiwi project" do
      let(:remote_meta_xml) {
        <<-XML_DATA
        <project name="home:cbruckmayer:fosdem">
          <title>FOSDEM 2017</title>
          <description/>
          <repository name="openSUSE_Leap_42.1">
            <path project="openSUSE:Leap:42.1" repository="standard"/>
            <arch>x86_64</arch>
          </repository>
          <repository name="images">
            <path project="openSUSE.org:openSUSE:Leap:42.1:Images" repository="standard"/>
            <path project="openSUSE.org:openSUSE:Leap:42.1:Update" repository="standard"/>
            <arch>x86_64</arch>
          </repository>
        </project>
        XML_DATA
      }
      let(:local_xml_meta) {
        <<-XML_DATA
        <project name="#{project}">
          <title>#{project.title}</title>
          <description/>
          <repository name="openSUSE_Leap_42.1">
            <path project="#{remote_project.name}:#{project}" repository="openSUSE_Leap_42.1"/>
            <arch>x86_64</arch>
          </repository>
          <repository name="images">
            <path project="openSUSE.org:openSUSE:Leap:42.1:Images" repository="standard"/>
            <path project="openSUSE.org:openSUSE:Leap:42.1:Update" repository="standard"/>
            <arch>x86_64</arch>
          </repository>
        </project>
      XML_DATA
      }
      let(:expected_xml) { Nokogiri::XML(local_xml_meta) }

      before do
        branch_remote_repositories
        project.reload
      end

      let(:new_repository) { project.repositories.second }
      let(:path_elements) { new_repository.path_elements.first.link }
      let(:path_elements2) { new_repository.path_elements.second.link }

      it { expect(new_repository.name).to eq("images") }
      it { expect(new_repository.architectures.first.name).to eq("x86_64") }
      it 'with correct path links' do
        expect(new_repository.path_elements.count).to eq(2)
        expect(path_elements.name).to eq("standard")
        expect(path_elements.remote_project_name).to eq("openSUSE:Leap:42.1:Images")
        expect(path_elements2.name).to eq("standard")
        expect(path_elements2.remote_project_name).to eq("openSUSE:Leap:42.1:Update")
      end
    end
  end

  describe '#self.valid_name?' do
    context "invalid" do
      it{ expect(Project.valid_name?(10)).to be(false) }

      it "has ::" do
        property_of {
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(1, 199)) { string(/[-+\w\.]/) }
          index = range(0, (string.length - 2))
          string[index] = string[index + 1] = ':'
          string
        }.check { |string|
          expect(Project.valid_name?(string)).to be(false)
        }
      end

      it "end with :" do
        property_of {
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 198)) { string(/[-+\w\.:]/) } + ':'
          guard string !~ /::/
          string
        }.check { |string|
          expect(Project.valid_name?(string)).to be(false)
        }
      end

      it "has an invalid character in first position" do
        property_of {
          string = sized(1) { string(/[-+\.:_]/) } + sized(range(0, 199)) { string(/[-+\w\.:]/) }
          guard !(string[-1] == ':' && string.length > 1) && string !~ /::/
          string
        }.check { |string|
          expect(Project.valid_name?(string)).to be(false)
        }
      end

      it "has more than 200 characters" do
        property_of {
          string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(200) { string(/[-+\w\.:]/) }
          guard string[-1] != ':' && string !~ /::/
          string
        }.check(3) { |string|
          expect(Project.valid_name?(string)).to be(false)
        }
      end

      it{ expect(Project.valid_name?('0')).to be(false) }
      it{ expect(Project.valid_name?('')).to be(false) }
    end

    it "valid" do
      property_of {
        string = sized(1) { string(/[a-zA-Z0-9]/) } + sized(range(0, 199)) { string(/[-+\w\.:]/) }
        guard string != '0' && string[-1] != ':' && !(/::/ =~ string)
        string
      }.check { |string|
        expect(Project.valid_name?(string)).to be(true)
      }
    end
  end

  describe '#deleted?' do
    it 'returns false if the project exists in the app' do
      expect(Project.deleted?(project.name)).to eq(false)
    end

    it 'returns false if _history file of project is empty' do
      allow_any_instance_of(ProjectFile).to receive(:to_s).with(deleted: 1).and_return(nil)
      expect(Project.deleted?('never-existed-before')).to eq(false)
    end

    it 'returns true if _history element has elements' do
      allow_any_instance_of(ProjectFile).to receive(:to_s).with(deleted: 1).and_return(
        "<revisionlist>\n  <revision rev=\"1\" vrev=\"\">\n    <srcmd5>d41d8cd98f00b204e9800998ecf8427e</srcmd5>\n    " \
        "<version></version>\n    <time>1498113679</time>\n    <user>Admin</user>\n    <comment>1</comment>\n  " \
        "</revision>\n</revisionlist>\n"
      )

      expect(Project.deleted?('never-existed-before')).to eq(true)
    end
  end

  describe '#restore' do
    let!(:admin_user) { create(:admin_user, login: 'Admin') }
    let!(:project_name) { 'project_used_for_restoration' }
    let(:project_meta) {
      <<-PROJECT_META_XML
        <project name=\"#{project_name}\">\n  <title></title>\n
        <description></description>\n  <person userid=\"Admin\" role=\"maintainer\" />\n</project>
      PROJECT_META_XML
    }

    before do
      allow(Backend::Connection).to receive(:post).and_return(nil)
      allow_any_instance_of(ProjectMetaFile).to receive(:to_s).and_return(project_meta)
      allow(Collection).to receive(:find).and_return(ActiveXML::Node.new('<collection/>'))
    end

    describe 'verifys call to backend' do
      it 'with option: user' do
        expect(Backend::Connection).to receive(:post).with("/source/#{project_name}?cmd=undelete&user=#{admin_user}")
        Project.restore(project_name, user: admin_user.login)
      end

      it 'with option: comment' do
        expect(Backend::Connection).to receive(:post).with("/source/#{project_name}?cmd=undelete&comment=schaeuferle_mag_jeder")
        Project.restore(project_name, comment: 'schaeuferle_mag_jeder')
      end

      it 'with options: user and comment' do
        expect(Backend::Connection).to receive(:post).with("/source/#{project_name}?cmd=undelete&user=#{admin_user}&comment=schaeuferle_mag_jeder")
        Project.restore(project_name, user: admin_user.login, comment: 'schaeuferle_mag_jeder')
      end
    end

    describe 'project meta' do
      it 'gets properly updated' do
        expect_any_instance_of(Project).to receive(:update_from_xml!).with(
          {"name" => "project_used_for_restoration", "title" => {}, "description" => {}, "person" => {"userid" => "Admin", "role" => "maintainer"}}
        )

        Project.restore(project_name)
      end
    end

    describe 'restoration of project with packages' do
      let(:packages_collection) {
        <<-PACKAGES_COLLECTION
        <collection>
          <package name="test-package1" project="#{project_name}">
            <title></title>
            <description></description>
          </package>
          <package name="test-package2" project="#{project_name}">
            <title></title>
            <description></description>
          </package>
        </collection>
        PACKAGES_COLLECTION
      }

      let(:package1_meta) {
        "<package name=\"test-package1\" project=\"#{project_name}\">\n  <title/>\n  <description/>\n</package>\n"
      }

      let(:package2_meta) {
        "<package name=\"test-package2\" project=\"#{project_name}\">\n  <title/>\n  <description/>\n</package>\n"
      }

      before do
        allow(Collection).to receive(:find).and_return(ActiveXML::Node.new(packages_collection))
        allow(PackageMetaFile).to receive(:new).with(project_name: project_name, package_name: 'test-package1').and_return(
          "<package name=\"test-package1\" project=\"#{project_name}\"><title></title>  <description></description></package>"
        )
        allow(PackageMetaFile).to receive(:new).with(project_name: project_name, package_name: 'test-package2').and_return(
          "<package name=\"test-package2\" project=\"#{project_name}\"><title></title>  <description></description></package>"
        )
      end

      it 'creates package records in the database' do
        project = Project.restore(project_name)

        expect(project.packages.find_by(name: 'test-package1')).to be_a(Package)
        expect(project.packages.find_by(name: 'test-package2')).to be_a(Package)
      end

      it 'verifys the meta of restored packages' do
        Project.restore(project_name)

        expect(Package.find_by(name: 'test-package1').render_xml).to eq(package1_meta)
        expect(Package.find_by(name: 'test-package2').render_xml).to eq(package2_meta)
      end
    end
  end
end

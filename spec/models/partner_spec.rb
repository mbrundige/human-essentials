# == Schema Information
#
# Table name: partners
#
#  id                          :integer          not null, primary key
#  email                       :string
#  name                        :string
#  notes                       :text
#  quota                       :integer
#  send_reminders              :boolean          default(FALSE), not null
#  status                      :integer          default("uninvited")
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  default_storage_location_id :bigint
#  organization_id             :integer
#  partner_group_id            :bigint
#

RSpec.describe Partner, type: :model, skip_seed: true do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:partner_group).optional }
    it { should have_many(:item_categories).through(:partner_group) }
    it { should have_many(:requestable_items).through(:item_categories).source(:items) }
    it { should have_many(:requests) }
    it { should have_many(:distributions) }
    it { should have_many(:requests) }
  end

  context "Validations >" do
    it "must belong to an organization" do
      expect(build(:partner, organization_id: nil)).not_to be_valid
    end

    it "requires a unique name within an organization" do
      expect(build(:partner, name: nil)).not_to be_valid
      create(:partner, name: "Foo")
      expect(build(:partner, name: "Foo")).not_to be_valid
    end

    it "does not require a unique name between organizations" do
      create(:partner, name: "Foo")
      expect(build(:partner, name: "Foo", organization: build(:organization))).to be_valid
    end

    it "still requires a unique email between organizations" do
      create(:partner, name: "Foo", email: "foo@example.com")
      expect(build(:partner, name: "Foo", email: "foo@example.com", organization: build(:organization))).to_not be_valid
      expect(build(:partner, name: "Foo", email: "FOO@example.com", organization: build(:organization))).to_not be_valid
    end

    it "requires a unique email that is formatted correctly" do
      expect(build(:partner, email: nil)).not_to be_valid
      create(:partner, email: "foo@bar.com")
      expect(build(:partner, email: "foo@bar.com")).not_to be_valid
      expect(build(:partner, email: "boooooooooo")).not_to be_valid
    end

    it "validates the quota is a number but it is not required" do
      is_expected.to validate_numericality_of(:quota)
      expect(build(:partner, email: "foo@bar.com", quota: "")).to be_valid
    end
  end

  describe "Filters" do
    describe "by_status" do
      it "yields partners with the provided status" do
        create(:partner, status: :invited)
        create(:partner, status: :approved)
        expect(Partner.by_status('invited').count).to eq(1)
      end
      it "yields deactivated partner when deactivated status provided" do
        create(:partner, status: :deactivated)
        create(:partner, status: :approved)
        expect(Partner.by_status('deactivated').count).to eq(1)
      end
    end
  end

  describe '#deactivated?' do
    subject { partner.deactivated? }
    let(:partner) { build(:partner) }

    context "when the status is 'deactivated'" do
      before do
        partner.status = 'deactivated'
      end

      it 'should return true' do
        expect(subject).to eq(true)
      end
    end

    context "when the status is not 'deactivated'" do
      before do
        partner.status = 'invited'
      end

      it 'should return false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#deletable?' do
    context 'when status is not uninvited' do
      it 'should return false' do
        expect(build(:partner, status: :invited)).not_to be_deletable
        expect(build(:partner, status: :awaiting_review)).not_to be_deletable
        expect(build(:partner, status: :approved)).not_to be_deletable
        expect(build(:partner, status: :error)).not_to be_deletable
        expect(build(:partner, status: :recertification_required)).not_to be_deletable
        expect(build(:partner, status: :deactivated)).not_to be_deletable
      end
    end

    context 'when status is uninvited' do
      let(:partner) { create(:partner, :uninvited, without_profile: true) }

      context 'when it has no other associations' do
        it 'should return true' do
          expect(partner).to be_deletable
        end
      end

      context 'when it has a request' do
        it 'should return false' do
          create(:request, partner: partner)
          expect(partner.reload).not_to be_deletable
        end
      end
      context 'when it has a distribution' do
        it 'should return false' do
          create(:distribution, partner: partner)
          expect(partner.reload).not_to be_deletable
        end
      end
      context 'when it has a profile but no users' do
        it 'should return true' do
          create(:partners_partner, essentials_bank_id: partner.organization_id, partner_id: partner.id, name: partner.name)
          expect(partner.reload).to be_deletable
        end
      end
      context 'when it has a profile and users' do
        it 'should return false' do
          partners_partner = create(:partners_partner, essentials_bank_id: partner.organization_id, partner_id: partner.id, name: partner.name)
          create(:partners_user, email: partner.email, name: partner.name, partner: partners_partner)
          expect(partner.reload).not_to be_deletable
        end
      end
    end
  end

  describe '#invite_new_partner' do
    let(:partner) { create(:partner) }

    it "should call the User.invite! when the partner is changed" do
      allow(User).to receive(:invite!)
      partner.email = "randomtest@email.com"
      partner.save!
      expect(User).to have_received(:invite!).with(
        {email: "randomtest@email.com", partner: partner.profile}
      )
    end
  end

  describe '#profile' do
    subject { partner.profile }
    let(:partner) { create(:partner) }

    it 'should return the associated Partners::Partner record' do
      expect(subject).to eq(Partners::Partner.find_by(partner_id: partner.id))
    end
  end

  describe '#primary_partner_user' do
    subject { partner.primary_partner_user }
    let(:partner) { create(:partner) }

    it 'should return the asssociated primary User' do
      partner_users = ::User.where(partner_id: partner.profile.id)
      expect(partner_users).to include(subject)
    end
  end

  describe "import_csv" do
    let(:organization) { create(:organization) }

    it "imports partners from a csv file and prevents multiple imports" do
      before_import = Partner.count
      import_file_path = Rails.root.join("spec", "fixtures", "files", "partners.csv")
      data = File.read(import_file_path, encoding: "BOM|UTF-8")
      csv = CSV.parse(data, headers: true)
      Partner.import_csv(csv, organization.id)
      expect(Partner.count).to eq before_import + 3
      import_file_path2 = Rails.root.join("spec", "fixtures", "files", "partners_with_duplicates.csv")
      data2 = File.read(import_file_path2, encoding: "BOM|UTF-8")
      csv2 = CSV.parse(data2, headers: true)
      Partner.import_csv(csv2, organization.id)
      expect(Partner.count).to eq before_import + 4
    end

    it "imports partners from a csv file with BOM encodings" do
      import_file_path = Rails.root.join("spec", "fixtures", "files", "partners_with_bom_encoding.csv")
      data = File.read(import_file_path, encoding: "BOM|UTF-8")
      csv = CSV.parse(data, headers: true)
      expect do
        Partner.import_csv(csv, organization.id)
      end.to change { Partner.count }.by(20)
    end
  end

  describe "#csv_export_attributes" do
    let!(:partner) { create(:partner) }

    let(:contact_name) { "Jon Ralfeo" }
    let(:contact_email) { "jon@entertainment720.com" }
    let(:contact_phone) { "1231231234" }

    before do
      partner.profile.update({
                               program_contact_name: contact_name,
                               program_contact_email: contact_email,
                               program_contact_phone: contact_phone
                             })
    end

    it "includes contact person information from parnerbase" do
      expect(partner.csv_export_attributes).to include(contact_name)
      expect(partner.csv_export_attributes).to include(contact_phone)
      expect(partner.csv_export_attributes).to include(contact_email)
    end
  end

  describe '#quantity_year_to_date' do
    let(:partner) { create(:partner) }
    before do
      create(:distribution, :with_items, partner: partner)
      create(:distribution, :with_items, partner: partner)
      create(:distribution, :with_items, partner: partner)
    end

    it "includes all item quantities for the given year" do
      expect(partner.quantity_year_to_date).to eq(300)
    end

    it "does not include quantities from last year" do
      LineItem.last.update(created_at: Time.zone.today.beginning_of_year - 20)
      expect(partner.quantity_year_to_date).to eq(200)
    end
  end

  describe "ActiveStorage validation" do
    it "validates that attachments are pdf or docs" do
      partner = build(:partner, documents: [Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/logo.jpg"), "image/jpeg")])

      expect(partner).to_not be_valid

      partner = build(:partner, documents: [Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/dbase.pdf"), "application/pdf")])

      expect(partner).to be_valid
    end
  end
end

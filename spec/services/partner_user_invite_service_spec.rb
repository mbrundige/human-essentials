require "rails_helper"

describe PartnerUserInviteService, skip_seed: true do
  let(:partner) { create(:partner) }
  let(:email) { Faker::Internet.email }
  let!(:partner_user) { instance_spy(PartnerUser) }

  describe "#call" do
    subject { described_class.new(partner: partner, email: email).call }

    context "when the partner user exist in database" do
      before do
        allow(PartnerUser).to receive(:find_by).with(email: email, partner: partner.profile).and_return(partner_user)
      end

      it "calls invite! partner user method" do
        subject
        expect(partner_user).to have_received(:invite!)
      end
    end

    context "when the partner user doesnt exist in database" do
      before do
        allow(PartnerUser).to receive(:invite!)
        allow(PartnerUser).to receive(:find_by).with(email: email, partner: partner.profile)
      end

      it "calls invite! PartnerUser class method" do
        subject
        expect(PartnerUser).to have_received(:invite!).with(email: email, partner: partner.profile)
      end
    end
  end
end

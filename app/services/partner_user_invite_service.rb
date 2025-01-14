class PartnerUserInviteService
  include ServiceObjectErrorsMixin

  def initialize(partner:, email:)
    @partner = partner
    @email = email
  end

  def call
    if existing_partner_user.present?
      existing_partner_user.invite!
    else
      PartnerUser.invite!(email: email, partner: partner.profile)
    end
  end

  private

  attr_reader :partner, :email

  def existing_partner_user
    @existing_partner_user ||= PartnerUser.find_by(email: email, partner: partner.profile)
  end
end

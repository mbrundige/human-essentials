class DistributionPolicy < ApplicationPolicy
  def edit
    return true if user.has_role?(:super_admin)

    user.has_role?(:org_admin) && user.organization_id == record.id
  end

end

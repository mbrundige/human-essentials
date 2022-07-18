class MergeUsers < ActiveRecord::Migration[7.0]
  def change

    klass = Class.new(Partners::Base) do
      self.table_name = 'partner_users'
    end

    # ignore password issues for now
    User.define_method(:password_required?) { false }

    klass.all.each do |user|
      begin
        main_user = ::User.unscoped.find_by(email: user.email)
        if main_user.nil?
          attrs = user.attributes.except('id').merge(discarded_at: nil)
          # null constraint on name for User table doesn't exist for Partner User table
          attrs['name'] ||= "CHANGEME"
          main_user = ::User.new(attrs)
          main_user.save!
          Partners::Request.where(partner_user_id: user.id).
            update_all(partner_user_id: main_user.id, updated_at: Time.zone.now)
        else
          main_user.partner_id = user.partner_id
          main_user.save!
        end
      end
    end

  end
end

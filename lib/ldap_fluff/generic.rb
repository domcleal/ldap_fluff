class LdapFluff::Generic
  attr_accessor :ldap, :member_service

  def initialize(config = {})
    @ldap = Net::LDAP.new(:host       => config.host,
                          :base       => config.base_dn,
                          :port       => config.port,
                          :encryption => config.encryption)
    @attr_login = config.attr_login
    @group_base = (config.group_base.empty? ? config.base_dn : config.group_base)
    @member_service = self.class::MemberService.new(@ldap, config)
  end

  def user_exists?(uid)
    @member_service.find_user(uid)
    true
  rescue self.class::MemberService::UIDNotFoundException
    false
  end

  def group_exists?(gid)
    @member_service.find_group(gid)
    true
  rescue self.class::MemberService::GIDNotFoundException
    false
  end

  def groups_for_uid(uid)
    @member_service.find_user_groups(uid)
  rescue self.class::MemberService::UIDNotFoundException
    return []
  end

  def users_for_gid(gid)
    return [] unless group_exists?(gid)
    search = @member_service.find_group(gid).last

    method = [:member, :ismemberof,
              :memberof, :memberuid].find { |m| search.respond_to? m } or
             raise 'Group does not have any members'

    users_from_search_results(search, method)
  end

  def includes_cn?(cn)
    filter = Net::LDAP::Filter.eq('cn', cn)
    @ldap.search(:base => @ldap.base, :filter => filter).present?
  end

  def service_bind
    unless @anon || bind?(@bind_user, @bind_pass)
      raise UnauthenticatedException,
            "Could not bind to #{class_name} user #{@bind_user}"
    end
  end

  private
  def class_name
    self.class.name.split('::').last
  end

  def users_from_search_results(search, method)
    members = search.send method
    if method == :memberuid
      # memberuid contains an array ['user1','user2'], no need to parse it
      members
    else
      @member_service.get_logins(members)
    end
  end

  class UnauthenticatedException < LdapFluff::Error
  end
end


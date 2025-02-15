# frozen_string_literal: true

module CloudConnector
  extend self

  GITLAB_REALM_SAAS = 'saas'
  GITLAB_REALM_SELF_MANAGED = 'self-managed'

  def gitlab_realm
    gitlab_realm_saas? ? GITLAB_REALM_SAAS : GITLAB_REALM_SELF_MANAGED
  end

  def headers(user)
    {
      'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
      'X-Gitlab-Instance-Id' => Gitlab::GlobalAnonymousId.instance_id,
      'X-Gitlab-Realm' => ::CloudConnector.gitlab_realm,
      'X-Gitlab-Version' => Gitlab.version_info.to_s
    }.tap do |result|
      result['X-Gitlab-Global-User-Id'] = Gitlab::GlobalAnonymousId.user_id(user) if user
    end
  end

  ###
  # Returns required HTTP header fields when making AI requests through Cloud Connector.
  #
  #  user - User making the request, may be null.
  #  namespace_ids - Namespaces for which to return the maximum allowed Duo seat count.
  #                  This should only be set when the request is made on gitlab.com.
  def ai_headers(user, namespace_ids: [])
    effective_seat_count = GitlabSubscriptions::AddOnPurchase.maximum_duo_seat_count(
      namespace_ids: namespace_ids
    )
    headers(user).merge(
      'X-Gitlab-Duo-Seat-Count' => effective_seat_count.to_s,
      'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => namespace_ids.join(',')
    )
  end

  def gitlab_realm_saas?
    Gitlab.org_or_com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
  end

  def self_managed_cloud_connected?
    !gitlab_realm_saas? && !::Gitlab::AiGateway.self_hosted_url.present?
  end
end

# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionsController < ApplicationController
    include InternalRedirect
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include ActionView::Helpers::SanitizeHelper

    SUCCESS_SUBSCRIPTION = 'Success: subscription'
    SUCCESS_ADDON = 'Success: add-on'

    layout 'minimal'

    # Skip user authentication if the user is currently verifying their identity
    # by providing a payment method as part of a three-stage (payment method,
    # phone number, and email verification) identity verification process.
    # Authentication is skipped since active_for_authentication? is false at
    # this point and becomes true only after the user completes the verification
    # process.
    before_action :authenticate_user!, except: :new, unless: :identity_verification_request?

    before_action :load_eligible_groups, only: :new

    feature_category :subscription_management
    urgency :low

    def new
      return ensure_registered! unless current_user.present?

      @namespace =
        if params[:namespace_id]
          namespace_id = params[:namespace_id].to_i
          @eligible_groups.find { |n| n.id == namespace_id }
        end

      if params[:plan_id]
        redirect_to GitlabSubscriptions::PurchaseUrlBuilder.new(
          plan_id: sanitize(params[:plan_id]),
          namespace: @namespace
        ).build
      else
        redirect_to Gitlab::Saas.about_pricing_url
      end
    end

    def buy_minutes
      return render_404 unless ci_minutes_plan_data.present?

      # At the moment of this comment the account id is directly available to the view.
      # This might change in the future given the intention to associate the account id to the namespace.
      # See: https://gitlab.com/gitlab-org/gitlab/-/issues/338546#note_684762160
      result = find_group(plan_id: ci_minutes_plan_data["id"])

      return render_404 if result[:namespace].nil?

      redirect_to GitlabSubscriptions::PurchaseUrlBuilder.new(
        plan_id: ci_minutes_plan_data['id'],
        namespace: result[:namespace]
      ).build(transaction: 'ci_minutes')
    end

    def buy_storage
      return render_404 unless storage_plan_data.present?

      # At the moment of this comment the account id is directly available to the view.
      # This might change in the future given the intention to associate the account id to the namespace.
      # See: https://gitlab.com/gitlab-org/gitlab/-/issues/338546#note_684762160
      result = find_group(plan_id: storage_plan_data["id"])

      return render_404 if result[:namespace].nil?

      redirect_to GitlabSubscriptions::PurchaseUrlBuilder.new(
        plan_id: storage_plan_data["id"],
        namespace: result[:namespace]
      ).build(transaction: 'storage')
    end

    def payment_form
      response = client.payment_form_params(params[:id], current_user&.id)
      render json: response[:data]
    end

    def payment_method
      response = client.payment_method(params[:id])
      render json: response[:data]
    end

    def validate_payment_method
      user_id = identity_verification_request? ? identity_verification_user.id : current_user.id

      response = client.validate_payment_method(params[:id], { gitlab_user_id: user_id })

      render json: response
    end

    def create
      current_user.update(setup_for_company: true) if params[:setup_for_company]
      group = params[:selected_group] ? current_group : create_group

      return not_found if group.nil?

      unless group.persisted?
        track_purchase message: group.errors.full_messages.to_s
        return render json: group.errors.to_json
      end

      response = GitlabSubscriptions::CreateService.new(
        current_user,
        group: group,
        customer_params: customer_params,
        subscription_params: subscription_params,
        idempotency_key: params[:idempotency_key]
      ).execute

      if response[:success]
        track_purchase message: track_success_message, namespace: group
        response[:data] = { location: redirect_location(group) }
      else
        track_purchase message: response.dig(:data, :errors), namespace: group
      end

      render json: response[:data]
    end

    private

    def track_purchase(message:, namespace: nil)
      Gitlab::Tracking.event(
        self.class.name,
        'click_button',
        label: 'confirm_purchase',
        property: message,
        user: current_user,
        namespace: namespace
      )
    end

    def track_success_message
      addon? ? SUCCESS_ADDON : SUCCESS_SUBSCRIPTION
    end

    def addon?
      Gitlab::Utils.to_boolean(subscription_params[:is_addon], default: false)
    end

    def redirect_location(group)
      return safe_redirect_path(params[:redirect_after_success]) if params[:redirect_after_success]

      plan_id, quantity = subscription_params.values_at(:plan_id, :quantity)
      return group_billings_path(group, plan_id: plan_id, purchased_quantity: quantity) if params[:selected_group]

      edit_gitlab_subscriptions_group_path(
        group.path, plan_id: plan_id, quantity: quantity, new_user: params[:new_user]
      )
    end

    def customer_params
      params.require(:customer).permit(:country, :address_1, :address_2, :city, :state, :zip_code, :company)
    end

    def subscription_params
      params.require(:subscription)
            .permit(:plan_id, :is_addon, :payment_method_id, :quantity, :source, :promo_code)
            .merge(params.permit(:active_subscription))
    end

    def find_group(plan_id:)
      selected_group = current_user.owned_groups.top_level.find(params[:selected_group])

      result = GitlabSubscriptions::FetchPurchaseEligibleNamespacesService
        .new(user: current_user, plan_id: plan_id, namespaces: Array(selected_group))
        .execute

      return {} unless result.success?

      result.payload.first || {}
    end

    def current_group
      find_group(plan_id: subscription_params[:plan_id])[:namespace]
    end

    def create_group
      name = Namespace.clean_name(params[:setup_for_company] ? customer_params[:company] : current_user.name)
      path = Namespace.clean_path(name)

      response = Groups::CreateService.new(
        current_user, name: name, path: path, organization_id: Current.organization_id
      ).execute

      response[:group]
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end

    def ci_minutes_plan_data
      strong_memoize(:ci_minutes_plan_data) do
        plan_response = client.get_plans(tags: ['CI_1000_MINUTES_PLAN'])

        plan_response[:success] ? plan_response[:data].first : nil
      end
    end

    def storage_plan_data
      strong_memoize(:storage_plan_data) do
        plan_response = client.get_plans(tags: ['STORAGE_PLAN'])

        plan_response[:success] ? plan_response[:data].first : nil
      end
    end

    def load_eligible_groups
      return @eligible_groups = [] unless current_user

      @eligible_groups = fetch_eligible_groups
    end

    def fetch_eligible_groups
      candidate_groups = current_user.owned_groups.top_level.with_counts(archived: false)

      result = GitlabSubscriptions::FetchPurchaseEligibleNamespacesService
                 .new(user: current_user, namespaces: candidate_groups, any_self_service_plan: true)
                 .execute

      return [] unless result.success?

      # rubocop:disable Rails/Pluck -- doing .pluck is only valid inside model hence disabling
      (result.payload || []).map { |h| h[:namespace] }
      # rubocop:enable Rails/Pluck
    end

    def ensure_registered!
      store_location_for(:user, request.fullpath)

      redirect_to new_user_registration_path
    end

    def identity_verification_request?
      # true only for actions used to verify a user's credit card
      return false unless %w[payment_form validate_payment_method].include?(action_name)

      identity_verification_user.present? && !identity_verification_user.credit_card_verified?
    end

    def identity_verification_user
      strong_memoize(:identity_verification_user) do
        User.find_by_id(session[:verification_user_id])
      end
    end
  end
end

GitlabSubscriptions::SubscriptionsController.prepend_mod

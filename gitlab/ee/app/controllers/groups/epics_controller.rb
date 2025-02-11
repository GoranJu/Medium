# frozen_string_literal: true

class Groups::EpicsController < Groups::ApplicationController
  include IssuableActions
  include IssuableCollections
  include ToggleAwardEmoji
  include ToggleSubscriptionAction
  include EpicsActions
  include DescriptionDiffActions

  before_action :check_epics_available!
  before_action :epic, except: [:index, :create, :new, :bulk_update]
  before_action :authorize_update_issuable!, only: :update
  before_action :authorize_create_epic!, only: [:create, :new]
  before_action :verify_group_bulk_edit_enabled!, only: [:bulk_update]
  before_action :set_summarize_notes_feature_flag, only: :show
  before_action :set_work_item_epics_feature_flag, only: [:show, :new]
  after_action :log_epic_show, only: :show

  before_action do
    push_frontend_feature_flag(:preserve_markdown, @group)
    push_frontend_feature_flag(:notifications_todos_buttons, current_user)
    push_force_frontend_feature_flag(:namespace_level_work_items, epic_work_items_enabled?)
    push_force_frontend_feature_flag(:glql_integration, @group&.glql_integration_feature_flag_enabled?)
    push_force_frontend_feature_flag(:continue_indented_text, @group&.continue_indented_text_feature_flag_enabled?)
    push_frontend_feature_flag(:work_item_epics_list, @group)
    push_force_frontend_feature_flag(:work_items_alpha, group.work_items_alpha_feature_flag_enabled?)
    push_frontend_feature_flag(:epics_list_drawer, @group)
    push_frontend_feature_flag(:bulk_update_work_items_mutation, @group)
    push_frontend_feature_flag(:work_item_description_templates, @group)
    push_frontend_feature_flag(:custom_fields_feature, @group&.root_ancestor)
  end

  before_action only: :show do
    push_frontend_ability(ability: :measure_comment_temperature, resource: epic, user: current_user)
  end

  before_action only: :index do
    push_force_frontend_feature_flag(:namespace_level_work_items, epic_work_items_enabled?)
  end

  feature_category :portfolio_management
  urgency :default, [:show, :new, :realtime_changes]
  urgency :low, [:discussions]
  def show
    respond_to do |format|
      format.html do
        next render_as_work_item if work_item_view?
      end
      format.json do
        render json: serializer.represent(epic)
      end
    end
  end

  def new
    if work_item_view?
      render 'groups/work_items/show'
    else
      @noteable = Epic.new
    end
  end

  def index
    if Feature.enabled?(:work_item_epics_list, @group) && epic_work_items_enabled?
      render 'work_items_index'
    else
      render 'index'
    end
  end

  def create
    @epic = ::Epics::CreateService.new(group: @group, current_user: current_user, params: epic_params).execute

    if @epic.persisted?
      render json: {
        web_url: group_epic_path(@group, @epic)
      }
    else
      head :unprocessable_entity
    end
  end

  private

  def epic_work_items_enabled?
    !!@group&.namespace_work_items_enabled?
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def epic
    @issuable = @epic ||= @group.epics.find_by(iid: params[:epic_id] || params[:id])

    return render_404 unless can?(current_user, :read_epic, @epic)

    @noteable = @epic
  end
  # rubocop: enable CodeReuse/ActiveRecord
  alias_method :issuable, :epic
  alias_method :awardable, :epic
  alias_method :subscribable_resource, :epic

  def subscribable_project
    nil
  end

  def render_as_work_item
    @work_item = ::WorkItems::WorkItemsFinder
      .new(current_user, group_id: group.id)
      .execute
      .with_work_item_type
      .find_by_iid(epic.iid)

    if Feature.enabled?(:work_item_epics_list, @group) && epic_work_items_enabled?
      render 'work_items_index'
    else
      render 'groups/work_items/show'
    end
  end

  def epic_params
    params.require(:epic).permit(*epic_params_attributes)
  end

  def epic_params_attributes
    [
      :color,
      :title,
      :description,
      :start_date_fixed,
      :start_date_is_fixed,
      :due_date_fixed,
      :due_date_is_fixed,
      :state_event,
      :confidential,
      { label_ids: [],
        update_task: [:index, :checked, :line_number, :line_source] }
    ]
  end

  def serializer
    EpicSerializer.new(current_user: current_user)
  end

  def discussion_serializer
    Epics::DiscussionSerializer.new(
      project: nil,
      noteable: issuable,
      current_user: current_user,
      note_entity: EpicNoteEntity
    )
  end

  def update_service
    ::Epics::UpdateService.new(group: @group, current_user: current_user, params: epic_params.to_h)
  end

  def finder_type
    EpicsFinder
  end

  def sorting_field
    :epics_sort
  end

  def log_epic_show
    return unless current_user && @epic

    ::Gitlab::Search::RecentEpics.new(user: current_user).log_view(@epic)
  end

  def authorize_create_epic!
    return render_404 unless can?(current_user, :create_epic, group)
  end

  def work_item_view?
    return false if params[:force_legacy_view].present? && params[:force_legacy_view]

    epic_work_items_enabled?
  end

  def verify_group_bulk_edit_enabled!
    render_404 unless group.licensed_feature_available?(:group_bulk_edit)
  end

  def set_work_item_epics_feature_flag
    push_force_frontend_feature_flag(:work_item_epics, work_item_view?)
  end

  def set_summarize_notes_feature_flag
    push_force_frontend_feature_flag(:summarize_comments, can?(current_user, :summarize_comments, epic))
  end
end

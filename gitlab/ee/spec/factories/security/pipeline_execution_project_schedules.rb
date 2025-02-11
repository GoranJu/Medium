# frozen_string_literal: true

FactoryBot.define do
  factory :security_pipeline_execution_project_schedule, class: 'Security::PipelineExecutionProjectSchedule' do
    project

    association :security_policy, :pipeline_execution_schedule_policy
  end
end

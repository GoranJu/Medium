# frozen_string_literal: true

module QA
  module EE
    module Page
      module Trials
        class Select < QA::Page::Base
          include QA::Page::Component::Dropdown

          view 'ee/app/components/gitlab_subscriptions/trials/trial_form_component.html.haml' do
            element 'trial-form'
            element 'start-your-free-trial-button'
          end

          def trial_for=(group)
            within_element('trial-form') do
              expand_select_list
              select_item(group)
            end
          end

          def click_start_your_free_trial_button
            click_element('start-your-free-trial-button')
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ValueStreamActions, feature_category: :team_planning do
  let_it_be(:group) { build(:group) }
  let_it_be(:current_user) { build(:user) }

  subject(:controller_class) do
    Class.new(ApplicationController) do
      include Analytics::CycleAnalytics::ValueStreamActions

      def call_data_attributes
        data_attributes
      end
    end
  end

  describe '#data_attributes' do
    subject(:controller) { controller_class.new }

    before do
      allow(controller).to receive(:namespace).and_return(group)
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(controller).to receive(:vsa_path).and_return('gdk.test/test_path')
    end

    it 'returns the expected result for new endpoint' do
      expect(controller.call_data_attributes.keys).to contain_exactly(
        :default_stages,
        :namespace,
        :vsa_path,
        :is_edit_page
      )
    end

    it 'returns the expected result for edit endpoint' do
      allow(controller).to receive(:action_name).and_return('edit')
      allow(controller).to receive(:value_stream).and_return(
        build(:cycle_analytics_value_stream, name: 'test', namespace: group)
      )

      expect(controller.call_data_attributes.keys).to contain_exactly(
        :default_stages,
        :namespace,
        :vsa_path,
        :is_edit_page,
        :value_stream
      )
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Groups::Update, feature_category: :groups_and_projects do
  include GraphqlHelpers
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { full_path: group.full_path } }

  describe '#resolve' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.new(object: group, context: query_context, field: nil).resolve(**params) }

    context 'when changing duo_features_enabled settings' do
      shared_examples 'updating the group duo_features_enabled settings' do
        it 'updates the settings' do
          expect { subject }
            .to change { group.reload.duo_features_enabled }.to(false)
            .and change { group.reload.lock_duo_features_enabled }.to(true)
        end

        it 'returns no errors' do
          expect(subject).to eq(errors: [], group: group)
        end
      end

      shared_examples 'denying access to group' do
        it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      let_it_be(:params) do
        {
          full_path: group.full_path,
          duo_features_enabled: false,
          lock_duo_features_enabled: true
        }
      end

      where(:user_role, :shared_examples_name) do
        :owner      | 'updating the group duo_features_enabled settings'
        :maintainer | 'denying access to group'
        :developer  | 'denying access to group'
        :reporter   | 'denying access to group'
        :guest      | 'denying access to group'
        :anonymous  | 'denying access to group'
      end

      with_them do
        before do
          group.send("add_#{user_role}", current_user) unless user_role == :anonymous
        end

        it_behaves_like params[:shared_examples_name]
      end
    end
  end
end

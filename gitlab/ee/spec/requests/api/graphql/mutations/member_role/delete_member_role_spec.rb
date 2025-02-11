# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'deleting member role', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:member_role) { create(:member_role, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let(:arguments) do
    {
      id: member_role.to_global_id.to_s
    }
  end

  let(:mutation) { graphql_mutation(:member_role_delete, arguments) }

  subject(:mutation_response) { graphql_mutation_response(:member_role_delete) }

  context 'without the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'with maintainer role' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      context 'with valid arguments' do
        it 'returns success' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response).to be_present
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['memberRole']).to be_present
          expect(graphql_errors).to be_nil
        end

        it 'deletes the member role' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { MemberRole.count }.by(-1)
        end
      end

      context 'with invalid arguments' do
        let(:arguments) { { id: 'gid://gitlab/MemberRole/-1' } }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors).to be_present
        end
      end

      context 'with missing arguments' do
        let(:arguments) { {} }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors).to be_present
        end
      end
    end
  end
end

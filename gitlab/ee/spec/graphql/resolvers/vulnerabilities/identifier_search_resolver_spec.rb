# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Vulnerabilities::IdentifierSearchResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_2) { create(:project, namespace: group) }
  let_it_be(:other_project) { create(:project, namespace: create(:group)) }

  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  before_all do
    group.add_maintainer(user)

    create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-23')
    create(:vulnerabilities_identifier, project: project_2, external_type: 'cwe', name: 'CWE-24')
    create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-25')
    create(:vulnerabilities_identifier, project: other_project, external_type: 'cwe', name: 'CWE-26')

    create(:vulnerability_statistic, project: project)
    create(:vulnerability_statistic, project: project_2)
    create(:vulnerability_statistic, project: project)
    create(:vulnerability_statistic, project: other_project)
  end

  describe '#resolve' do
    subject(:search_results) { resolve(described_class, obj: obj, args: args, ctx: { current_user: current_user }) }

    shared_examples 'handles invalid search input' do
      context 'when the name argumentis less than 3 characters' do
        let(:args) { { name: 'ab' } }
        let(:error_msg) { 'Name should be greater than 3 characters.' }

        it 'raises an error for insufficient name length' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, error_msg) do
            search_results
          end
        end
      end
    end

    shared_examples 'handles a disabled feature flag' do
      context 'when the feature flag is disabled' do
        let(:error_msg) { /Feature flag `#{feature_flag}` is disabled for the #{obj.class.name}./i }

        before do
          stub_feature_flags(feature_flag => false)
        end

        it 'raises an error for the disabled feature flag' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, error_msg) do
            search_results
          end
        end
      end
    end

    let!(:args) { { name: 'cwe' } }

    context 'when the current user has access' do
      let(:current_user) { user }

      context 'with a group' do
        let(:obj) { group }

        it 'fetches matching identifier names' do
          expect(search_results).to contain_exactly('CWE-23', 'CWE-24', 'CWE-25')
        end

        context 'when flags that solve cross-joins are disabled' do
          before do
            stub_feature_flags(sum_vulnerability_count_for_group_using_vulnerability_statistics: false)
            stub_feature_flags(search_identifier_name_in_group_using_vulnerability_statistics: false)
          end

          it 'fetches matching identifier names' do
            expect(search_results).to contain_exactly('CWE-23', 'CWE-24', 'CWE-25')
          end
        end

        it_behaves_like 'handles invalid search input'
        it_behaves_like 'handles a disabled feature flag' do
          let(:feature_flag) { :vulnerability_filtering_by_identifier_group }
        end
      end

      context 'with a project' do
        let(:obj) { project }

        it 'fetches matching identifier names' do
          expect(search_results).to contain_exactly('CWE-23', 'CWE-25')
        end

        it_behaves_like 'handles invalid search input'
      end
    end

    context 'when the current user does not have access' do
      let(:current_user) { other_user }

      context 'with a group' do
        let(:obj) { group }

        it 'returns resource not available' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            search_results
          end
        end
      end
    end
  end
end

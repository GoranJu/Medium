# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::BranchRules::SquashOptions::UpdateService, feature_category: :source_code_management do
  describe '#execute' do
    let_it_be(:protected_branch) { create :protected_branch }
    let_it_be(:project) { protected_branch.project }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }

    let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
    let(:current_user) { maintainer }
    let(:squash_option) { ::Projects::BranchRules::SquashOption.squash_options['always'] }

    subject(:execute) do
      described_class.new(branch_rule, squash_option: squash_option, current_user: current_user).execute
    end

    context 'when the user is not authorized' do
      let(:current_user) { developer }

      it 'returns an error response' do
        result = execute

        expect(result.message).to eq(described_class::AUTHORIZATION_ERROR_MESSAGE)
        expect(result).to be_error
      end
    end

    context 'when there is a squash option' do
      let!(:existing_squash_option) do
        create :branch_rule_squash_option, project: project, protected_branch: protected_branch
      end

      it 'updates the squash option' do
        expect { execute }
          .to change { protected_branch.squash_option.squash_option }.from('default_off').to('always')
          .and not_change { ::Projects::BranchRules::SquashOption.count }.from(1)

        expect(execute).to be_success
      end
    end

    it 'creates a squash option' do
      expect { execute }
        .to change { protected_branch&.squash_option&.squash_option }.from(nil).to('always')
        .and change { ::Projects::BranchRules::SquashOption.count }.from(0).to(1)

      expect(execute).to be_success
    end
  end
end

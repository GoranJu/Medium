# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting merge access levels for a branch protection', feature_category: :source_code_management do
  it_behaves_like 'a GraphQL query for access levels', :merge do
    include_examples 'AccessLevel type objects contains user and group', :merge
  end

  context 'when the branch_rule_squash_settings not enabled' do
    before do
      stub_feature_flags(branch_rule_squash_settings: false)
    end

    it_behaves_like 'a GraphQL query for access levels', :merge do
      include_examples 'AccessLevel type objects contains user and group', :merge
    end
  end
end

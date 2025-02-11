# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::Project, feature_category: :shared do
  let_it_be(:project) { create(:project) }

  let(:options) { {} }
  let(:developer) { create(:user, developer_of: project) }
  let(:guest) { create(:user, guest_of: project) }

  let(:entity) do
    ::API::Entities::Project.new(project, options)
  end

  subject { entity.as_json }

  context 'compliance_frameworks' do
    context 'when project has a compliance framework' do
      let(:project) { create(:project, :with_sox_compliance_framework) }

      it 'is an array containing all the compliance frameworks' do
        expect(subject[:compliance_frameworks]).to match_array(['SOX'])
      end
    end

    context 'when project has compliance frameworks' do
      let_it_be(:project) { create(:project, :with_multiple_compliance_frameworks) }

      it 'is an array containing all the compliance frameworks' do
        expect(subject[:compliance_frameworks]).to contain_exactly('SOX', 'GDPR')
      end
    end

    context 'when project has no compliance framework' do
      let(:project) { create(:project) }

      it 'is empty array when project has no compliance framework' do
        expect(subject[:compliance_frameworks]).to eq([])
      end
    end
  end

  describe 'ci_restrict_pipeline_cancellation_role' do
    let(:options) { { current_user: current_user } }

    context 'when user has maintainer permission or above' do
      let(:current_user) { project.owner }

      context 'when available' do
        before do
          mock_available
        end

        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to eq 'developer' }
      end

      context 'when not available' do
        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be nil }
      end
    end

    context 'when user permission is below maintainer' do
      let(:current_user) { developer }

      context 'when available' do
        before do
          mock_available
        end

        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be nil }
      end

      context 'when not available' do
        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be nil }
      end
    end

    def mock_available
      allow_next_instance_of(Ci::ProjectCancellationRestriction) do |cr|
        allow(cr).to receive(:feature_available?).and_return(true)
      end
    end
  end

  describe 'secret_push_protection_enabled' do
    let_it_be(:project) { create(:project) }
    let(:options) { { current_user: current_user } }

    before do
      stub_licensed_features(secret_push_protection: true)
    end

    shared_examples 'returning nil' do
      it 'returns nil' do
        expect(subject[:secret_push_protection_enabled]).to be(nil)
      end
    end

    context 'when user does not have access' do
      context 'when project does not have proper license' do
        let(:current_user) { developer }

        before do
          stub_licensed_features(secret_push_protection: false)
        end

        it_behaves_like 'returning nil'
      end

      context 'when user is guest' do
        let(:current_user) { guest }

        it_behaves_like 'returning nil'
      end
    end

    context 'when user is developer' do
      let(:current_user) { developer }

      it 'returns a boolean' do
        expect(subject[:secret_push_protection_enabled]).to be_in([true, false])
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AutocompleteService, feature_category: :groups_and_projects do
  let_it_be(:group, refind: true) { create(:group, :nested, :private, avatar: fixture_file_upload('spec/fixtures/dk.png')) }
  let_it_be(:project) { create(:project, group: group) }

  let(:user) { create(:user) }
  let!(:epic) { create(:epic, group: group, author: user) }
  let_it_be(:issue) { create(:issue, project: project) }

  subject { described_class.new(project, user) }

  before do
    group.add_developer(user)
  end

  describe '#epics' do
    let(:expected_attributes) { [:iid, :title, :group_id, :group] }

    before do
      stub_licensed_features(epics: true)
    end

    it 'returns nothing if not allowed' do
      guest = create(:user)

      epics = described_class.new(project, guest).epics

      expect(epics).to be_empty
    end

    it 'returns epics from group' do
      result = subject.epics.map { |epic| epic.slice(expected_attributes) }

      expect(result).to contain_exactly(epic.slice(expected_attributes))
    end
  end

  describe '#iterations', feature_category: :team_planning do
    let_it_be(:cadence) { create(:iterations_cadence, group: group) }
    let_it_be(:open_iteration) { create(:iteration, iterations_cadence: cadence) }
    let_it_be(:closed_iteration) { create(:iteration, :closed, iterations_cadence: cadence) }
    let_it_be(:other_iteration) do
      other_group = create(:group, :private)
      create(:iteration, iterations_cadence: create(:iterations_cadence, group: other_group))
    end

    subject { described_class.new(project, user).iterations }

    context 'when the iterations feature is unavailable' do
      before do
        stub_licensed_features(iterations: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when the iterations feature is available' do
      before do
        stub_licensed_features(iterations: true)
      end

      it { is_expected.to contain_exactly(open_iteration) }
    end
  end

  describe '#commands' do
    context 'with Amazon Q enabled' do
      let(:amazon_q_enabled) { true }

      subject(:commands) { described_class.new(project, user).commands(issue) }

      before do
        allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
      end

      context 'with an issue' do
        it 'contains /q issue subcommands' do
          expect(commands).to include(a_hash_including(
            name: :q,
            params: ['<dev | transform>']
          ))
        end
      end

      context 'with a merge request' do
        let(:issue) { create(:merge_request, source_project: project, target_project: project) }

        it 'contains /q merge request subcommands' do
          expect(commands).to include(a_hash_including(
            name: :q,
            params: ['<dev | fix | review | test>']
          ))
        end
      end
    end
  end
end

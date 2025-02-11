# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::MergeRequestsService, feature_category: :code_review_workflow do
  include Gitlab::Routing

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:author) { create(:user) }

  let(:noteable) { create(:merge_request, source_project: project, target_project: project) }

  let(:service) { described_class.new(noteable: noteable, container: project, author: author) }

  describe '#approvals_reset' do
    let(:cause) { :new_push }
    let_it_be(:approvers) { create_list(:user, 3) }

    subject(:approvals_reset_note) do
      described_class
        .new(noteable: noteable, container: project, author: author)
        .approvals_reset(cause, approvers)
    end

    it_behaves_like 'a system note' do
      let(:action) { 'approvals_reset' }
    end

    it 'sets the note text' do
      expect(approvals_reset_note.note)
        .to eq("reset approvals from #{approvers.map(&:to_reference).to_sentence} by pushing to the branch")
    end

    context 'when cause is not new_push' do
      let(:cause) { :something_else }

      it 'returns nil' do
        expect(approvals_reset_note).to be_nil
      end
    end

    context 'when there are no approvers' do
      let_it_be(:approvers) { [] }

      it 'returns nil' do
        expect(approvals_reset_note).to be_nil
      end
    end
  end

  describe '#override_requested_changes' do
    let(:overriding) { true }

    subject(:override_requested_changes_note) do
      described_class
        .new(noteable: noteable, container: project, author: author)
        .override_requested_changes(overriding)
    end

    it_behaves_like 'a system note' do
      let(:action) { 'override' }
    end

    it 'sets the note text' do
      expect(override_requested_changes_note.note)
        .to eq('bypassed reviews on this merge request')
    end

    context 'when removing override' do
      let(:overriding) { false }

      it 'sets the note text' do
        expect(override_requested_changes_note.note)
          .to eq('removed the bypass on this merge request')
      end
    end
  end
end

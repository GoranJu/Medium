# frozen_string_literal: true

RSpec.shared_examples 'a work item custom field value' do |factory:|
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:work_item) }
    it { is_expected.to validate_presence_of(:custom_field) }

    describe '#copy_namespace_from_work_item' do
      let(:work_item) { create(:work_item) }

      it 'copies namespace_id from the associated work item' do
        expect do
          subject.work_item = work_item
          subject.valid?
        end.to change { subject.namespace_id }.from(nil).to(work_item.namespace_id)
      end
    end
  end

  describe '.for_field_and_work_item' do
    let(:custom_field_1) { create(:custom_field) }
    let(:custom_field_2) { create(:custom_field) }
    let(:work_item_1) { create(:work_item) }
    let(:work_item_2) { create(:work_item) }

    it 'returns records matching the custom_field_id and work_item_id' do
      matching_value = create(factory, custom_field: custom_field_1, work_item: work_item_1)

      create(factory, custom_field: custom_field_1, work_item: work_item_2)
      create(factory, custom_field: custom_field_2, work_item: work_item_1)
      create(factory, custom_field: custom_field_2, work_item: work_item_2)

      expect(
        described_class.for_field_and_work_item(custom_field_1, work_item_1)
      ).to contain_exactly(matching_value)
    end
  end
end

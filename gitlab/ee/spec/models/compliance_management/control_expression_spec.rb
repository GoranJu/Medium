# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ControlExpression, feature_category: :compliance_management do
  let(:id) { 'test_id' }
  let(:name) { 'Test Control' }
  let(:expression) { { field: 'test_field', operator: '=', value: true } }

  subject(:control_expression) { described_class.new(id: id, name: name, expression: expression) }

  describe 'class inclusions' do
    it 'includes GlobalID::Identification' do
      expect(described_class.included_modules).to include(GlobalID::Identification)
    end
  end

  describe '#initialize' do
    it 'sets the id, name, and expression' do
      expect(control_expression.id).to eq(id)
      expect(control_expression.name).to eq(name)
      expect(control_expression.expression).to eq(expression)
    end
  end

  describe 'attribute readers' do
    it { is_expected.to respond_to(:id) }
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:expression) }
  end

  describe '#to_global_id' do
    it 'returns the id as a string' do
      expect(control_expression.to_global_id).to eq(id.to_s)
    end
  end
end

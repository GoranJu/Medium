# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ArchivedRecord, feature_category: :vulnerability_management do
  subject { build(:vulnerability_archived_record) }

  it { is_expected.to belong_to(:project).required }
  it { is_expected.to belong_to(:archive).class_name('Vulnerabilities::Archive').required }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability_identifier) }
    it { is_expected.to validate_uniqueness_of(:vulnerability_identifier) }
    it { is_expected.to validate_presence_of(:data) }
  end
end

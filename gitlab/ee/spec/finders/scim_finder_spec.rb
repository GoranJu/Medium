# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScimFinder, feature_category: :system_access do
  include LoginHelpers

  let_it_be(:group) { create(:group) }
  let(:unused_params) { double }

  subject(:finder) { described_class.new(group) }

  describe '#initialize' do
    context 'on Gitlab.com', :saas do
      it 'raises error for group not passed' do
        expect { described_class.new }.to raise_error(ArgumentError)
      end
    end

    context 'on self managed' do
      it 'does not raise error when group is not passed' do
        expect { described_class.new }.not_to raise_error { ArgumentError }
      end
    end
  end

  describe '#search' do
    context 'without a SAML provider' do
      it 'returns an empty scim identity relation' do
        expect(finder.search(unused_params)).to eq ScimIdentity.none
      end
    end

    context 'SCIM/SAML is not enabled' do
      before do
        create(:saml_provider, group: group, enabled: false)
      end

      it 'returns an empty scim identity relation' do
        expect(finder.search(unused_params)).to eq ScimIdentity.none
      end
    end

    context 'with SCIM enabled' do
      let_it_be(:saml_provider) { create(:saml_provider, group: group) }
      let_it_be(:user) { create(:user, username: 'foo', email: 'bar@example.com') }
      let_it_be(:scim_identity) { create(:scim_identity, group: group, user: user) }

      context 'when separate_group_scim_table feature flag is disabled' do
        before do
          stub_feature_flags(separate_group_scim_table: false)
        end

        context 'filtering by ID or externalId' do
          it 'allows lookup by id and externalId' do
            expect(finder.search(filter: "id eq #{scim_identity.extern_uid}").first).to eq scim_identity
            expect(finder.search(filter: "externalId eq #{scim_identity.extern_uid}").first).to eq scim_identity
          end
        end

        context 'filtering by userName' do
          it 'finds by username' do
            expect(finder.search(filter: "userName eq \"#{scim_identity.user.username}\"").first).to eq scim_identity
          end

          it 'finds by email address' do
            expect(finder.search(filter: "userName eq #{scim_identity.user.email}").first).to eq scim_identity
          end

          it 'finds by username derived from email' do
            email = "#{scim_identity.user.username}@example.com"
            expect(finder.search(filter: "userName eq #{email}").first).to eq scim_identity
          end

          it 'finds by extern_uid' do
            expect(finder.search(filter: "userName eq \"#{scim_identity.extern_uid}\"").first).to eq scim_identity
          end

          context 'when email id is invalid' do
            it 'returns an empty scim identity relation' do
              expect(User).not_to receive(:find_by_any_email)
              expect(User).to receive(:find_by_username).once
              expect(finder.search(filter: "userName eq abc@example")).to be_empty
            end
          end
        end

        context 'with unsupported filters' do
          it 'raises an error for unsupported filter' do
            expect { finder.search(filter: 'id ne 1').count }.to raise_error(ScimFinder::UnsupportedFilter)
          end

          it 'raises an error for unsupported attribute path' do
            expect do
              finder.search(filter: 'displayName eq "name"').count
            end.to raise_error(ScimFinder::UnsupportedFilter)
          end
        end

        context 'without filters' do
          it 'returns all related scim identities' do
            create_list(:scim_identity, 4, group: group)
            expect(finder.search({}).count).to eq 5
          end
        end

        context 'without filters or group parameter' do
          subject(:finder) { described_class.new }

          before do
            stub_basic_saml_config
          end

          it 'returns all related scim identities' do
            create_list(:scim_identity, 4)
            expect(finder.search({}).count).to eq 5
          end
        end
      end
    end
  end
end

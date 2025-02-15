# frozen_string_literal: true

RSpec.shared_examples 'service account creation success' do
  before do
    # Even when email confirmation is enabled, service accounts with
    # auto-generated email addresses will be confirmed.
    stub_application_setting_enum('email_confirmation_setting', 'hard')
  end

  it 'creates a service account successfully', :aggregate_failures do
    result = service.execute

    expect(result.status).to eq(:success)
    expect(result.payload[:user].confirmed?).to eq(true)
    expect(result.payload[:user].composite_identity_enforced?).to eq(false)
    expect(result.payload[:user].user_type).to eq('service_account')
    expect(result.payload[:user].external).to eq(true)
    expect(result.payload[:user].namespace.organization).to eq(organization)
  end

  include_examples 'username and email pair is generated by Gitlab::Utils::UsernameAndEmailGenerator' do
    subject { service.execute.payload[:user] }

    let(:email_domain) { "noreply.#{Gitlab.config.gitlab.host}" }
  end
end

RSpec.shared_examples 'service account creation with customized params' do
  subject(:service) { described_class.new(current_user, params) }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:username_prefix) { "service_account" }
  let_it_be(:email) { "service_account@example.com" }

  let(:params) do
    {
      name: 'John Doe',
      username: 'test',
      email: email,
      organization_id: organization.id,
      composite_identity_enforced: true
    }
  end

  context 'when email confirmation is off' do
    before do
      stub_application_setting_enum('email_confirmation_setting', 'off')
    end

    it 'creates a service account successfully', :aggregate_failures do
      result = service.execute
      user = service.execute.payload[:user]

      expect(result.status).to eq(:success)
      expect(user.confirmed?).to eq(true)
      expect(user.user_type).to eq('service_account')
      expect(user.external).to eq(true)
      expect(user.composite_identity_enforced?).to eq(true)
    end
  end

  context 'when email confirmation is on' do
    before do
      stub_application_setting_enum('email_confirmation_setting', 'hard')
    end

    it 'creates a service account successfully', :aggregate_failures do
      result = service.execute
      user = service.execute.payload[:user]

      expect(result.status).to eq(:success)
      expect(user.confirmed?).to eq(false)
      expect(user.user_type).to eq('service_account')
      expect(user.external).to eq(true)
      expect(user.composite_identity_enforced?).to eq(true)
    end
  end

  it 'sets user attributes according to supplied params' do
    user = service.execute.payload[:user]

    expect(user.username).to eq(params[:username])
    expect(user.name).to eq(params[:name])
    expect(user.email).to eq(params[:email])
  end

  context 'when username is not supplied' do
    let_it_be(:params) do
      {
        name: 'John Doe',
        organization_id: organization.id
      }
    end

    it 'sets auto generated username' do
      result = service.execute
      user = result.payload[:user]

      expect(result.status).to eq(:success)
      expect(user.username).to start_with(username_prefix)
      expect(user.name).to eq(params[:name])
    end
  end

  context 'when name is not supplied' do
    let_it_be(:params) do
      {
        username: 'test',
        organization_id: organization.id
      }
    end

    it 'sets auto generated username' do
      result = service.execute
      user = result.payload[:user]

      expect(result.status).to eq(:success)
      expect(user.name).to eq("Service account user")
      expect(user.username).to eq(params[:username])
    end

    it 'throws error when record with same username already exists' do
      create(:user, { username: 'test' })

      result = service.execute

      expect(result.status).to eq(:error)
      expect(result.message).to eq('Username has already been taken')
    end

    it 'throws error when the username is assigned to another project pages unique domain' do
      # Simulate the existing domain being in use
      create(:project_setting, pages_unique_domain: 'test')

      result = service.execute

      expect(result.status).to eq(:error)
      expect(result.message).to eq('Username has already been taken')
    end
  end

  context 'when email is not supplied' do
    let_it_be(:params) do
      {
        name: 'John Doe',
        organization_id: organization.id
      }
    end

    it 'sets auto generated email' do
      result = service.execute
      user = result.payload[:user]

      expect(result.status).to eq(:success)
      expect(user.username).to start_with(username_prefix)
      expect(user.name).to eq(params[:name])
      expect(user.email).to start_with('service_account')
    end
  end
end

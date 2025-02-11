# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::SelfHostedModelsMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin/ai/self_hosted_models',
    title: s_('Admin|Self-hosted models'),
    icon: 'machine-learning'

  it_behaves_like 'Admin menu without sub menus', active_routes: { controller: :self_hosted_models }
end

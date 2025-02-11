# frozen_string_literal: true

RSpec.shared_examples 'a query filtered by hidden' do
  context 'when user can admin all resources' do
    before do
      allow(user).to receive(:can_admin_all_resources?).and_return(true)
    end

    it 'does not apply hidden filters' do
      assert_names_in_query(subject, without: %w[filters:not_hidden])
    end
  end

  context 'when user cannot admin all resources' do
    it 'applies hidden filters' do
      assert_names_in_query(subject, with: %w[filters:not_hidden])
    end
  end
end

RSpec.shared_examples 'a query filtered by archived' do
  context 'when include_archived is set to true' do
    let(:options) { base_options.merge(include_archived: true) }

    it 'does not apply non-archived filter' do
      assert_names_in_query(subject, without: %w[filters:non_archived])
    end
  end

  context 'when include_archived is not set' do
    it 'applies non archived filters' do
      assert_names_in_query(subject, with: %w[filters:non_archived])
    end
  end
end

RSpec.shared_examples 'a query filtered by state' do
  context 'when state option is not provided' do
    it 'does not apply state filters' do
      assert_names_in_query(subject, without: %w[filters:state])
    end
  end

  context 'when state option is provided' do
    let(:options) { base_options.merge(state: 'opened') }

    it 'applies state filters' do
      assert_names_in_query(subject, with: %w[filters:state])
    end
  end
end

# requires authorized_project and private_project project defined in caller
RSpec.shared_examples 'a query filtered by confidentiality' do
  context 'when user has role which allows viewing confidential data' do
    it 'applies all confidential filters' do
      assert_names_in_query(subject,
        with: %w[
          filters:non_confidential
          filters:confidential
          filters:confidential:as_author
          filters:confidential:as_assignee
        ])
    end

    context 'for all projects in the query' do
      let(:project_ids) { [authorized_project.id] }

      it 'does not apply the confidential filters' do
        assert_names_in_query(subject, without: %w[
          filters:confidential
          filters:non_confidential
          filters:confidential:as_author
          filters:confidential:as_assignee
          filters:confidential:project:membership:id
        ])
      end
    end
  end

  context 'when user does not have role' do
    let(:project_ids) { [private_project.id] }

    it 'applies all confidential filters' do
      assert_names_in_query(subject, with: %w[
        filters:non_confidential
        filters:confidential
        filters:confidential:as_author
        filters:confidential:as_assignee
        filters:confidential:project:membership:id
      ])
    end
  end

  context 'when there is no user' do
    let(:user) { nil }
    let(:project_ids) { [private_project.id] }

    it 'only applies the non-confidential filter' do
      assert_names_in_query(subject, with: %w[filters:non_confidential],
        without: %w[
          filters:confidential
          filters:confidential:as_author
          filters:confidential:as_assignee
          filters:confidential:project:membership:id
        ])
    end
  end
end

# requires group, authorized_project and private_project project defined in caller
RSpec.shared_examples 'a query filtered by project authorization' do
  context 'for global search' do
    let(:options) do
      base_options.merge(search_level: :global, project_ids: [authorized_project.id, private_project.id])
    end

    it 'applies authorization filters' do
      assert_names_in_query(build, with: %w[filters:permissions:global])
    end

    context 'when project_ids is passed :any' do
      let(:options) do
        base_options.merge(search_level: :global, project_ids: [authorized_project.id, private_project.id])
      end

      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:permissions:global],
          without: %w[filters:level:group
            filters:permissions:group
            filters:level:project
            filters:permissions:project])
      end
    end
  end

  context 'for group search' do
    let(:options) do
      base_options.merge(search_level: :group, group_ids: [group.id],
        project_ids: [authorized_project.id, private_project.id])
    end

    it 'applies authorization filters' do
      assert_names_in_query(build, with: %w[filters:level:group filters:permissions:group],
        without: %w[filters:permissions:global
          filters:level:project
          filters:permissions:project])
    end
  end

  context 'for project search' do
    let(:options) do
      base_options.merge(search_level: :project, project_ids: [authorized_project.id], group_ids: [group.id])
    end

    it 'applies authorization filters' do
      assert_names_in_query(build, with: %w[filters:level:project filters:permissions:project],
        without: %w[filters:permissions:global
          filters:level:group
          filters:permissions:group])
    end
  end
end

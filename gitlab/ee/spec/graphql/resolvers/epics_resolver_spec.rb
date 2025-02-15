# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::EpicsResolver, feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user2) { create(:user) }

  context "with a group" do
    let_it_be_with_refind(:group) { create(:group) }

    let_it_be(:project) { create(:project, :public, group: group) }
    let_it_be(:epic1)   { create(:epic, group: group, state: :closed, title: 'first created', created_at: 3.days.ago, updated_at: 2.days.ago, start_date: 10.days.ago, end_date: 10.days.from_now) }
    let_it_be(:epic2)   { create(:epic, group: group, author: user2, title: 'second created', description: 'text 1', created_at: 2.days.ago, updated_at: 3.days.ago, start_date: 20.days.ago, end_date: 20.days.from_now) }

    before_all do
      group.add_developer(current_user)
    end

    before do
      stub_licensed_features(epics: true)
    end

    describe '#resolve' do
      it 'returns nothing when feature disabled' do
        stub_licensed_features(epics: false)

        expect(resolve_epics).to be_empty
      end

      it 'finds all epics' do
        expect(resolve_epics).to contain_exactly(epic1, epic2)
      end

      context 'with iid' do
        it 'finds a specific epic with iid' do
          expect(resolve_epics(iid: epic1.iid)).to contain_exactly(epic1)
        end

        it 'does not inflate the complexity' do
          field = Types::BaseField.new(name: 'test', type: GraphQL::Types::String, resolver_class: described_class, null: false, max_page_size: 100)

          expect(field.complexity.call({}, { iid: [epic1.iid] }, 5)).to eq 6
        end
      end

      context 'with iids' do
        it 'finds a specific epic with iids' do
          expect(resolve_epics(iids: [epic1.iid.to_s])).to contain_exactly(epic1)
        end

        it 'finds multiple epics with iids' do
          expect(resolve_epics(iids: [epic1.iid, epic2.iid]))
              .to contain_exactly(epic1, epic2)
        end

        it 'increases the complexity based on child_complexity and number of iids' do
          field = Types::BaseField.new(name: 'test', type: GraphQL::Types::String, resolver_class: described_class, null: false, max_page_size: 100)

          expect(field.complexity.call({}, { iids: [epic1.iid] }, 5)).to eq 6
          expect(field.complexity.call({}, { iids: [epic1.iid, epic2.iid] }, 5)).to eq 11
        end
      end

      context 'within timeframe' do
        let!(:epic1) { create(:epic, group: group, state: :closed, start_date: "2019-08-13", end_date: "2019-08-20") }
        let!(:epic2) { create(:epic, group: group, state: :closed, start_date: "2019-08-13", end_date: "2019-08-21") }

        context 'when timeframe start and end are present' do
          it 'returns epics within timeframe' do
            epics = resolve_epics(timeframe: { start: '2019-08-13', end: '2019-08-21' })

            expect(epics).to match_array([epic1, epic2])
          end
        end

        context 'with milestone' do
          let_it_be(:milestone) { create(:milestone, group: group) }

          before do
            create(:issue, project: project, milestone: milestone, epic: epic1)
            create(:issue, project: project, epic: epic2)
          end

          it 'filters epics by timeframe and issues milestone' do
            epics = resolve_epics(milestone_title: milestone.title, timeframe: { start: '2019-08-13', end: '2019-08-21' })

            expect(epics).to match_array([epic1])
          end
        end
      end

      context 'with state' do
        it 'lists epics with opened state' do
          epics = resolve_epics(state: 'opened')

          expect(epics).to match_array([epic2])
        end

        it 'lists epics with closed state' do
          epics = resolve_epics(state: 'closed')

          expect(epics).to match_array([epic1])
        end
      end

      it_behaves_like 'graphql query for searching issuables' do
        let_it_be(:parent) { group }
        let_it_be(:issuable1) { epic1 }
        let_it_be(:issuable2) { epic2 }
        let_it_be(:issuable3) { create(:epic, group: group, title: 'third', description: 'text 2') }
        let_it_be(:issuable4) { create(:epic, group: group) }

        let_it_be(:finder_class) { EpicsFinder }
        let_it_be(:optimization_param) { :attempt_group_search_optimizations }
      end

      context 'with author_username' do
        it 'filters epics by author' do
          user = create(:user)
          epic = create(:epic, group: group, author: user)
          create(:epic, group: group)

          epics = resolve_epics(author_username: user.username)

          expect(epics).to match_array([epic])
        end
      end

      context 'with label_name' do
        it 'filters epics by labels' do
          label_1 = create(:group_label, group: group)
          label_2 = create(:group_label, group: group)
          epic_1 = create(:labeled_epic, group: group, labels: [label_1, label_2])
          create(:labeled_epic, group: group, labels: [label_1])
          create(:labeled_epic, group: group)

          epics = resolve_epics(label_name: [label_1.title, label_2.title])

          expect(epics).to match_array([epic_1])
        end
      end

      context 'with my_reaction_emoji' do
        it 'filters epics by reaction emoji' do
          create(:award_emoji, name: 'man_in_business_suit_levitating', user: current_user, awardable: epic1)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, user: current_user, awardable: epic2)

          epics = resolve_epics(my_reaction_emoji: 'man_in_business_suit_levitating')

          expect(epics).to contain_exactly(epic1)
        end
      end

      context 'with milestone_title' do
        let_it_be(:milestone1) { create(:milestone, group: group) }

        it 'filters epics by issues milestone' do
          create(:issue, project: project, epic: epic2)
          create(:issue, project: project, milestone: milestone1, epic: epic1)

          epics = resolve_epics(milestone_title: milestone1.title)

          expect(epics).to match_array([epic1])
        end

        it 'returns empty result if milestone is not assigned to any epic issues' do
          milestone2 = create(:milestone, group: group)
          create(:issue, project: project, milestone: milestone1, epic: epic1)

          epics = resolve_epics(milestone_title: milestone2.title)

          expect(epics).to be_empty
        end
      end

      # subscribed filtering handled in request spec, ee/spec/requests/api/graphql/epics/epics_spec.rb

      context 'with sort' do
        let!(:epic3) { create(:epic, group: group, title: 'third', description: 'text 2', start_date: 30.days.ago, end_date: 30.days.from_now) }
        let!(:epic4) { create(:epic, group: group, title: 'forth created', description: 'four', start_date: 40.days.ago, end_date: 40.days.from_now) }

        it 'orders epics by start date in descending order' do
          epics = resolve_epics(sort: 'start_date_desc')

          expect(epics).to eq([epic1, epic2, epic3, epic4])
        end

        it 'orders epics by start date in ascending order' do
          epics = resolve_epics(sort: 'start_date_asc')

          expect(epics).to eq([epic4, epic3, epic2, epic1])
        end

        it 'orders epics by end date in descending order' do
          epics = resolve_epics(sort: 'end_date_desc')

          expect(epics).to eq([epic4, epic3, epic2, epic1])
        end

        it 'orders epics by end date in ascending order' do
          epics = resolve_epics(sort: 'end_date_asc')

          expect(epics).to eq([epic1, epic2, epic3, epic4])
        end

        it 'orders epics by title in descending order' do
          epics = resolve_epics(sort: 'title_desc')

          expect(epics).to eq([epic3, epic2, epic4, epic1])
        end

        it 'orders epics by title in ascending order' do
          epics = resolve_epics(sort: 'title_asc')

          expect(epics).to eq([epic1, epic4, epic2, epic3])
        end
      end

      context 'with subgroups' do
        let(:sub_group) { create(:group, parent: group) }
        let(:iids)      { [epic1, epic2].map(&:iid) }
        let!(:epic3)    { create(:epic, group: sub_group, iid: epic1.iid) }
        let!(:epic4)    { create(:epic, group: sub_group, iid: epic2.iid) }

        before do
          sub_group.add_developer(current_user)
        end

        it 'finds only the epics within the group we are looking at' do
          expect(resolve_epics(iids: iids)).to contain_exactly(epic1, epic2)
        end

        it 'returns all epics' do
          expect(resolve_epics).to contain_exactly(epic1, epic2, epic3, epic4)
        end

        it 'does not return subgroup epics when include_descendant_groups is false' do
          expect(resolve_epics(include_descendant_groups: false)).to contain_exactly(epic1, epic2)
        end

        it 'filters by milestones in subgroups' do
          subgroup_project = create(:project, group: sub_group)
          milestone = create(:milestone, group: sub_group)
          create(:issue, project: subgroup_project, epic: epic1, milestone: milestone)
          create(:issue, project: subgroup_project, epic: epic3, milestone: milestone)

          expect(resolve_epics(milestone_title: milestone.title)).to contain_exactly(epic1, epic3)
        end

        context 'when the resolved group is a subgroup' do
          it 'returns only the epics belonging to the subgroup by default' do
            expect(resolve_epics({}, sub_group)).to contain_exactly(epic3, epic4)
          end

          it 'returns the epics belonging to the ancestor groups when include_ancestor_groups is true' do
            expect(resolve_epics({ include_ancestor_groups: true }, sub_group)).to contain_exactly(epic1, epic2, epic3, epic4)
          end
        end
      end

      context 'with partial iids' do
        let!(:other_group) { create(:group, :private) }

        let!(:epic3) { create(:epic, group: group, iid: '1122') }
        let!(:epic4) { create(:epic, group: group, iid: '132') }
        let!(:epic5) { create(:epic, group: group, iid: '62') }
        let!(:epic6) { create(:epic, group: other_group, iid: '11999') }

        it 'returns the expected epics if just the first number of iid is requested' do
          epics = resolve_epics(iid_starts_with: '1')

          expect(epics).to contain_exactly(epic1, epic3, epic4)
        end

        it 'returns the expected epics if first two numbers of iid are requested' do
          epics = resolve_epics(iid_starts_with: '11')

          expect(epics).to contain_exactly(epic3)
        end

        it 'returns the expected epics if last two numbers of iid are given' do
          epics = resolve_epics(iid_starts_with: '32')

          expect(epics).to be_empty
        end

        it 'returns the expected epics if exact number of iid is given' do
          epics = resolve_epics(iid_starts_with: '62')

          expect(epics).to contain_exactly(epic5)
        end
      end

      context 'with `top_level_hierarchy_only` param set as `true`' do
        let(:args) { { top_level_hierarchy_only: true } }

        let_it_be(:child_epic) { create(:epic, group: group, title: 'child epic', parent: epic1) }
        let_it_be(:child_epic2) { create(:epic, group: group, title: 'child epic 2', parent: epic1) }

        it { expect(resolve_epics(args)).to contain_exactly(epic1, epic2) }

        context 'when a parent epic is present' do
          subject(:results) { resolve_epics(args, epic1) }

          it 'ignores `top_level_hierarchy_only` param and return all children of the given epic' do
            expect(results).to contain_exactly(child_epic, child_epic2)
          end
        end
      end
    end

    context 'with negated filters' do
      let_it_be(:group) { create(:group) }
      let_it_be(:author) { create(:user) }
      let_it_be(:label) { create(:group_label, group: group) }
      let_it_be(:epic_1) { create(:labeled_epic, group: group, labels: [label]) }
      let_it_be(:epic_2) { create(:epic, group: group, author: author) }
      let_it_be(:epic_3) { create(:epic, group: group) }
      let_it_be(:awarded_emoji) { create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: epic_3, user: current_user) }

      subject(:results) { resolve_epics(args) }

      context 'for label' do
        let(:args) { { not: { label_name: [label.title] } } }

        it { is_expected.to contain_exactly(epic_2, epic_3) }
      end

      context 'for author' do
        let(:args) { { not: { author_username: author.username } } }

        it { is_expected.to contain_exactly(epic_1, epic_3) }
      end

      context 'for emoji' do
        let(:args) { { not: { my_reaction_emoji: awarded_emoji.name } } }

        it { is_expected.to contain_exactly(epic_1, epic_2) }
      end
    end
  end

  context "when passing a non existent, batch loaded group" do
    let(:group) do
      BatchLoader::GraphQL.for("non-existent-path").batch do |_fake_paths, loader, _|
        loader.call("non-existent-path", nil)
      end
    end

    it "returns nil without breaking" do
      expect(resolve_epics(iids: ["don't", "break"])).to be_empty
    end
  end

  def resolve_epics(args = {}, obj = group, context = { current_user: current_user })
    resolve(described_class, obj: obj, args: args, ctx: context, arg_style: :internal)
  end
end

import projects from 'test_fixtures/api/users/projects/get.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import ProjectsListItem from '~/vue_shared/components/projects_list/projects_list_item.vue';
import ProjectListItemActions from 'ee/vue_shared/components/projects_list/project_list_item_actions.vue';
import { ACTION_DELETE } from '~/vue_shared/components/list_actions/constants';
import ProjectListItemDelayedDeletionModalFooter from 'ee_component/vue_shared/components/projects_list/project_list_item_delayed_deletion_modal_footer.vue';
import DeleteModal from '~/projects/components/shared/delete_modal.vue';

describe('ProjectsListItemEE', () => {
  let wrapper;

  const [mockProject] = convertObjectPropsToCamelCase(projects, { deep: true });
  const project = {
    ...mockProject,
    avatarLabel: mockProject.nameWithNamespace,
    isForked: false,
  };

  const defaultProps = { project };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectsListItem, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        AsyncDeleteModal: stubComponent(DeleteModal, {
          template: '<div><slot name="modal-footer"></slot></div>',
        }),
      },
    });
  };

  const findDeleteModal = () => wrapper.findComponent(DeleteModal);
  const findDelayedDeletionModalFooter = () =>
    wrapper.findComponent(ProjectListItemDelayedDeletionModalFooter);
  const findListActions = () => wrapper.findComponent(ProjectListItemActions);

  describe('ProjectListItemDelayedDeletionModalFooterEE', () => {
    const deleteProps = {
      project: {
        ...project,
        availableActions: [ACTION_DELETE],
        actionLoadingStates: { [ACTION_DELETE]: false },
      },
    };

    it('does not render modal footer when import is not resolved', () => {
      createComponent({ props: deleteProps });
      findListActions().vm.$emit('delete');

      expect(findDeleteModal().exists()).toBe(true);
      expect(findDelayedDeletionModalFooter().exists()).toBe(false);
    });

    it('renders modal footer once import is resolved', async () => {
      createComponent({ props: deleteProps });
      findListActions().vm.$emit('delete');

      await waitForPromises();

      expect(findDeleteModal().exists()).toBe(true);
      expect(findDelayedDeletionModalFooter().exists()).toBe(true);
    });
  });
});

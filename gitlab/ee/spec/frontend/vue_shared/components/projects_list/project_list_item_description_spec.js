import { GlIcon, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectListItemDescription from 'ee/vue_shared/components/projects_list/project_list_item_description.vue';
import ProjectListItemDescriptionCE from '~/vue_shared/components/projects_list/project_list_item_description.vue';

describe('ProjectListItemDescriptionEE', () => {
  let wrapper;

  const defaultProps = {
    project: { id: 1 },
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectListItemDescription, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlSprintf },
    });
  };

  const findProjectListItemDescriptionCE = () =>
    wrapper.findComponent(ProjectListItemDescriptionCE);
  const findGlIcon = () => wrapper.findComponent(GlIcon);

  describe('when pending deletion', () => {
    it('renders correct icon and scheduled for deletion information', () => {
      createComponent({
        props: {
          project: {
            ...defaultProps.project,
            markedForDeletionOn: '2024-12-24',
            permanentDeletionDate: '2024-12-31',
          },
        },
      });

      expect(findGlIcon().props('name')).toBe('calendar');
      expect(wrapper.text().replace(/\s+/g, ' ')).toBe('Scheduled for deletion on Dec 31, 2024');
    });
  });

  describe('when not pending deletion', () => {
    it('renders ProjectListItemDescriptionCE', () => {
      createComponent();

      expect(findProjectListItemDescriptionCE().exists()).toBe(true);
    });
  });
});

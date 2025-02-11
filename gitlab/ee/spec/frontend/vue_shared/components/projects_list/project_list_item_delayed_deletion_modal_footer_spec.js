import { GlLink, GlSprintf } from '@gitlab/ui';
import projects from 'test_fixtures/api/users/projects/get.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import ProjectListItemDelayedDeletionModalFooter from 'ee/vue_shared/components/projects_list/project_list_item_delayed_deletion_modal_footer.vue';

describe('ProjectListItemDelayedDeletionModalFooterEE', () => {
  let wrapper;

  const [project] = convertObjectPropsToCamelCase(projects, { deep: true });
  const MOCK_PERM_DELETION_DATE = '2024-03-31';
  const HELP_PATH = helpPagePath('user/project/working_with_projects', {
    anchor: 'restore-a-project',
  });

  const defaultProps = {
    project,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectListItemDelayedDeletionModalFooter, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findDelayedDeletionModalFooter = () => wrapper.findByTestId('delayed-delete-modal-footer');
  const findGlLink = () => wrapper.findComponent(GlLink);

  describe.each`
    isAdjournedDeletionEnabled | markedForDeletionOn | footer                                                                          | link
    ${false}                   | ${null}             | ${false}                                                                        | ${false}
    ${false}                   | ${'2024-03-24'}     | ${false}                                                                        | ${false}
    ${true}                    | ${null}             | ${`This project can be restored until ${MOCK_PERM_DELETION_DATE}. Learn more.`} | ${HELP_PATH}
    ${true}                    | ${'2024-03-24'}     | ${false}                                                                        | ${false}
  `(
    'when project.isAdjournedDeletionEnabled is $isAdjournedDeletionEnabled and project.markedForDeletionOn is $markedForDeletionOn',
    ({ isAdjournedDeletionEnabled, markedForDeletionOn, footer, link }) => {
      beforeEach(() => {
        createComponent({
          props: {
            project: {
              ...project,
              isAdjournedDeletionEnabled,
              markedForDeletionOn,
              permanentDeletionDate: MOCK_PERM_DELETION_DATE,
            },
          },
        });
      });

      it(`does ${footer ? 'render' : 'not render'} the delayed deletion modal footer`, () => {
        expect(
          findDelayedDeletionModalFooter().exists() && findDelayedDeletionModalFooter().text(),
        ).toBe(footer);
        expect(findGlLink().exists() && findGlLink().attributes('href')).toBe(link);
      });
    },
  );
});

import {
  GlBadge,
  GlLabel,
  GlButton,
  GlLink,
  GlPopover,
  GlSprintf,
  GlLoadingIcon,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import FrameworkInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/framework_info_drawer.vue';
import projectsInNamespaceWithFrameworkQuery from 'ee/compliance_dashboard/components/frameworks_report/graphql/projects_in_namespace_with_framework.query.graphql';
import { shallowMountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import { createFramework, mockPageInfo } from 'ee_jest/compliance_dashboard/mock_data';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('FrameworkInfoDrawer component', () => {
  let wrapper;

  function createMockApolloProvider({ projectsInNamespaceResolverMock }) {
    return createMockApollo([
      [projectsInNamespaceWithFrameworkQuery, projectsInNamespaceResolverMock],
    ]);
  }

  const $toast = {
    show: jest.fn(),
  };

  const GROUP_PATH = 'foo';
  const PROJECT_PATH = 'bar';

  const defaultFramework = createFramework({ id: 1, isDefault: true, projects: 3 });
  const nonDefaultFramework = createFramework({ id: 2 });
  const policiesCount =
    defaultFramework.scanExecutionPolicies.nodes.length +
    defaultFramework.scanResultPolicies.nodes.length +
    defaultFramework.pipelineExecutionPolicies.nodes.length +
    defaultFramework.vulnerabilityManagementPolicies.nodes.length;

  const findDefaultBadge = () => wrapper.findComponent(GlLabel);
  const findTitle = () => wrapper.findByTestId('framework-name');
  const findEditFrameworkBtn = () => wrapper.findByTestId('edit-framework-btn');

  const findIdSection = () => wrapper.findByTestId('sidebar-id');
  const findIdSectionTitle = () => wrapper.findByTestId('sidebar-id-title');
  const findFrameworkId = () => wrapper.findByTestId('framework-id');
  const findCopyIdButton = () => findIdSection().findComponent(GlButton);
  const findIdPopover = () => findIdSection().findComponent(GlPopover);

  const findDescriptionTitle = () => wrapper.findByTestId('sidebar-description-title');
  const findDescription = () => wrapper.findByTestId('sidebar-description');
  const findProjectsTitle = () => wrapper.findByTestId('sidebar-projects-title');
  const findProjectsLinks = () =>
    wrapper.findByTestId('sidebar-projects').findAllComponents(GlLink);
  const findLoadMoreButton = () =>
    extendedWrapper(wrapper.findByTestId('sidebar-projects')).findByText('Load more');
  const findProjectsCount = () => wrapper.findByTestId('sidebar-projects').findComponent(GlBadge);
  const findPoliciesTitle = () => wrapper.findByTestId('sidebar-policies-title');
  const findPoliciesLinks = () =>
    wrapper.findByTestId('sidebar-policies').findAllComponents(GlLink);
  const findPoliciesCount = () => wrapper.findByTestId('sidebar-policies').findComponent(GlBadge);
  const findPopover = () => wrapper.findByTestId('edit-framework-popover');

  const pendingPromiseMock = jest.fn().mockResolvedValue(new Promise(() => {}));

  const createComponent = ({
    props = {},
    projectsInNamespaceResolverMock = pendingPromiseMock,
  } = {}) => {
    const apolloProvider = createMockApolloProvider({
      projectsInNamespaceResolverMock,
    });

    wrapper = shallowMountExtended(FrameworkInfoDrawer, {
      apolloProvider,
      propsData: {
        showDrawer: true,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlButton,
        BButton: false,
      },
      provide: {
        groupSecurityPoliciesPath: '/group-policies',
      },
      mocks: {
        $toast,
      },
    });
  };

  describe('default framework display', () => {
    beforeEach(() => {
      createComponent({
        props: {
          groupPath: GROUP_PATH,
          projectPath: PROJECT_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
      });
    });

    describe('for drawer body content', () => {
      it('renders the title', () => {
        expect(findTitle().text()).toBe(defaultFramework.name);
      });

      it('renders the default badge', () => {
        expect(findDefaultBadge().exists()).toBe(true);
      });

      it('renders the edit framework button', () => {
        expect(findEditFrameworkBtn().exists()).toBe(true);
      });

      it('renders the ID accordion', () => {
        expect(findIdSectionTitle().text()).toBe('Compliance framework ID');
      });

      it('renders popover with a help link', () => {
        expect(findIdPopover().props('title')).toBe('Using the ID');
        expect(findIdPopover().text()).toMatchInterpolatedText(
          'Use the compliance framework ID in configuration or API requests. Learn more.',
        );
        expect(findIdPopover().findComponent(GlLink).attributes('href')).toBe(
          `${DOCS_URL_IN_EE_DIR}/user/application_security/policies/_index.html#scope`,
        );
      });

      it('renders the ID of the framework', () => {
        expect(findFrameworkId().text()).toBe('1');
      });

      it('renders the copy ID button', () => {
        expect(findCopyIdButton().text()).toBe('Copy ID');
      });

      it('calls copyIdToClipboard method when copy button is clicked', async () => {
        jest.spyOn(navigator.clipboard, 'writeText');
        await findCopyIdButton().vm.$emit('click');
        expect(navigator.clipboard.writeText).toHaveBeenCalledWith(1);
        expect($toast.show).toHaveBeenCalledWith('Framework ID copied to clipboard.');
      });

      it('renders the Description accordion', () => {
        expect(findDescriptionTitle().text()).toBe(`Description`);
        expect(findDescription().text()).toBe(defaultFramework.description);
      });

      it('renders the Associated Projects accordion', () => {
        expect(findProjectsTitle().text()).toBe(`Associated Projects`);
      });

      it('renders the Associated Projects count badge as loading', () => {
        expect(findProjectsCount().findComponent(GlLoadingIcon).exists()).toBe(true);
      });

      describe('Associated projects list when loaded', () => {
        const TOTAL_COUNT = 30;
        const makeProjectsListResponse = ({ pageInfo = mockPageInfo() } = {}) => {
          return {
            namespace: {
              __typename: 'Group',
              id: 'gid://gitlab/Group/1',
              projects: {
                ...defaultFramework.projects,
                count: TOTAL_COUNT,
                pageInfo,
              },
            },
          };
        };

        let projectsInNamespaceResolverMock;
        beforeEach(() => {
          projectsInNamespaceResolverMock = jest.fn().mockResolvedValue({
            data: makeProjectsListResponse(),
          });

          createComponent({
            projectsInNamespaceResolverMock,
            props: {
              groupPath: GROUP_PATH,
              projectPath: PROJECT_PATH,
              rootAncestor: {
                path: GROUP_PATH,
              },
              framework: defaultFramework,
            },
          });

          return waitForPromises();
        });

        it('renders the Associated Projects count', () => {
          expect(findProjectsCount().text()).toBe(`${TOTAL_COUNT}`);
        });

        it('renders the Associated Projects list', () => {
          expect(findProjectsLinks().wrappers).toHaveLength(3);
          expect(findProjectsLinks().at(0).text()).toContain(
            defaultFramework.projects.nodes[0].name,
          );
          expect(findProjectsLinks().at(0).attributes('href')).toBe(
            defaultFramework.projects.nodes[0].webUrl,
          );
        });

        describe('load more button', () => {
          const secondPageResponse = makeProjectsListResponse();
          secondPageResponse.namespace.projects.nodes =
            secondPageResponse.namespace.projects.nodes.map((node) => ({
              ...node,
              id: `gid://gitlab/Project/${node.id}-page-2`,
            }));

          beforeEach(() => {});
          it('renders when we have next page in list', () => {
            expect(findLoadMoreButton().exists()).toBe(true);
          });

          it('clicking button loads next page', async () => {
            projectsInNamespaceResolverMock.mockResolvedValueOnce({
              data: secondPageResponse,
            });
            await findLoadMoreButton().trigger('click');
            await waitForPromises();
            expect(projectsInNamespaceResolverMock).toHaveBeenCalledWith(
              expect.objectContaining({
                after: mockPageInfo().endCursor,
              }),
            );
          });

          it('does not render when we do not have next page', async () => {
            secondPageResponse.namespace.projects.pageInfo.hasNextPage = false;

            createComponent({
              projectsInNamespaceResolverMock: jest.fn().mockResolvedValue({
                data: secondPageResponse,
              }),
              props: {
                groupPath: GROUP_PATH,
                projectPath: PROJECT_PATH,
                rootAncestor: {
                  path: GROUP_PATH,
                },
                framework: defaultFramework,
              },
            });

            await waitForPromises();
            expect(findLoadMoreButton().exists()).toBe(false);
          });
        });
      });

      it('renders the Policies accordion', () => {
        expect(findPoliciesTitle().text()).toBe(`Policies`);
      });

      it('renders the Policies count', () => {
        expect(findPoliciesCount().text()).toBe(`${policiesCount}`);
      });

      it('renders the Policies list', () => {
        expect(findPoliciesLinks().wrappers).toHaveLength(policiesCount);
        expect(findPoliciesLinks().at(0).attributes('href')).toBe(`/bar/security/policies`);
        expect(findPoliciesLinks().at(1).attributes('href')).toBe(
          `/group-policies/${defaultFramework.scanResultPolicies.nodes[0].name}/edit?type=approval_policy`,
        );
      });

      it('does not render edit button popover', () => {
        expect(findPopover().exists()).toBe(false);
      });
    });
  });

  describe('framework display', () => {
    beforeEach(() => {
      createComponent({
        props: {
          framework: nonDefaultFramework,
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
        },
      });
    });

    describe('for drawer body content', () => {
      it('does not renders the default badge', () => {
        expect(findDefaultBadge().exists()).toBe(false);
      });
    });
  });

  describe('when viewing framework in a subgroup', () => {
    beforeEach(() => {
      createComponent({
        props: {
          groupPath: `${GROUP_PATH}/child`,
          rootAncestor: {
            path: GROUP_PATH,
            webUrl: `/web/${GROUP_PATH}`,
            name: 'Root',
          },
          framework: defaultFramework,
        },
      });
    });

    it('renders disabled edit framework button', () => {
      expect(findEditFrameworkBtn().props('disabled')).toBe(true);
    });

    it('renders popover', () => {
      expect(findPopover().text()).toMatchInterpolatedText(
        'The compliance framework must be edited in top-level group Root',
      );
    });
  });

  it('does not render associated projects when they are not provided', () => {
    createComponent({
      props: {
        groupPath: GROUP_PATH,
        rootAncestor: {
          path: GROUP_PATH,
        },
        framework: { ...defaultFramework, projects: null },
      },
    });

    expect(findProjectsTitle().exists()).toBe(false);
  });
});
